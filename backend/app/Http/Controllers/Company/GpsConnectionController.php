<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\ConnectGpsRequest;
use App\Http\Requests\Company\ImportGpsUnitsRequest;
use App\Http\Resources\GpsConnectionResource;
use App\Http\Resources\TruckResource;
use App\Models\GpsConnection;
use App\Models\Truck;
use App\Services\Gps\DeviceNameParser;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsProviderManager;
use App\Services\Gps\GpsUnit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Connect GPS (AppFlow §2.3): authorize a provider account, see the
 * vehicles on it, match them to registered trucks, import. One connection
 * covers a company's whole fleet (TRD §5.1) — trucks link to it
 * individually via gps_connection_id once matched.
 */
class GpsConnectionController extends Controller
{
    public function __construct(private readonly GpsProviderManager $providers) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return GpsConnectionResource::collection(
            $request->user()->transporterCompany->gpsConnections()->latest()->get()
        );
    }

    /**
     * Authorizes the account and returns every unit the provider can see,
     * each with a suggested truck match (plate text overlap) — the
     * company still picks/confirms via import(), nothing is linked yet.
     */
    public function connect(ConnectGpsRequest $request): JsonResponse
    {
        $company = $request->user()->transporterCompany;

        try {
            $provider = $this->providers->driver($request->string('provider')->toString());
            $units = $provider->listUnits($request->string('access_token')->toString());
        } catch (GpsProviderException $e) {
            throw ValidationException::withMessages(['access_token' => [$e->getMessage()]]);
        }

        $connection = GpsConnection::updateOrCreate(
            ['transporter_company_id' => $company->id, 'provider' => $request->string('provider')->toString()],
            ['access_token' => $request->string('access_token')->toString(), 'status' => 'connected', 'connected_at' => now(), 'last_synced_at' => now()]
        );

        $trucks = $company->trucks()->whereNull('gps_connection_id')->get();

        return response()->json([
            'connection' => (new GpsConnectionResource($connection))->resolve(),
            'units' => collect($units)->map(fn (GpsUnit $unit) => [
                'unit_id' => $unit->unitId,
                'name' => $unit->name,
                'has_position' => $unit->hasPosition(),
                'suggested_truck_id' => $this->suggestTruckMatch($unit, $trucks)?->id,
            ])->all(),
        ]);
    }

    /**
     * Links the confirmed unit-to-truck matches, or creates a brand-new
     * bare truck for a unit that doesn't correspond to anything already
     * registered (`create_new: true` — AppFlow §2.3's "anything not
     * matched stays 'GPS Tracking Not Available'" only ever meant "not
     * silently force-matched," not "must already exist as a truck").
     * Units left out of `matches` entirely are still just skipped, same
     * as before.
     *
     * A created truck is marked Truck.is_gps_imported — approved
     * immediately (a live GPS link is itself a real trust signal, and the
     * company needs it usable right away) but with no real make/model/
     * capacity/photos/documents yet. Manage Fleet surfaces an "Add
     * details" action for these; submitting it through the normal
     * TruckController::update() flow clears the flag and sends it through
     * real verification like any other truck.
     */
    public function import(ImportGpsUnitsRequest $request, GpsConnection $connection): AnonymousResourceCollection
    {
        $company = $request->user()->transporterCompany;
        abort_unless($connection->transporter_company_id === $company->id, 404);

        $updated = DB::transaction(function () use ($request, $connection, $company) {
            $trucks = collect();

            foreach ($request->validated('matches') as $match) {
                if (($match['create_new'] ?? false) === true) {
                    if (empty($match['unit_name'])) {
                        throw ValidationException::withMessages(['matches' => ['unit_name is required to add a unit as a new truck.']]);
                    }

                    $trucks->push(Truck::create([
                        'transporter_company_id' => $company->id,
                        'registration_number' => $this->extractPlate($match['unit_name']),
                        'make_model' => 'Pending real details',
                        'vehicle_type' => 'Flatbed',
                        'capacity_tons' => 10,
                        'verification_status' => 'approved',
                        'is_gps_imported' => true,
                        'gps_connection_id' => $connection->id,
                        'gps_unit_id' => $match['unit_id'],
                        'gps_status' => 'connected',
                    ]));

                    continue;
                }

                if (empty($match['truck_id'])) {
                    throw ValidationException::withMessages(['matches' => ['Each match needs either truck_id or create_new.']]);
                }

                $truck = Truck::where('transporter_company_id', $company->id)->find($match['truck_id']);
                if ($truck === null) {
                    throw ValidationException::withMessages(['matches' => ["Truck {$match['truck_id']} does not belong to your company."]]);
                }

                $truck->update([
                    'gps_connection_id' => $connection->id,
                    'gps_unit_id' => $match['unit_id'],
                    'gps_status' => 'connected',
                ]);
                $trucks->push($truck);
            }

            $connection->update(['last_synced_at' => now()]);

            return $trucks;
        });

        return TruckResource::collection($updated);
    }

    /**
     * A company disconnecting its GPS provider account entirely (Fleet
     * screen's Connect/Disconnect toggle) — every truck linked to this
     * connection drops back to "GPS off" (gps_connection_id/gps_unit_id
     * are left in place, so reconnecting the same provider can re-link
     * them without losing that history), and the connection itself is
     * marked 'disconnected' rather than deleted so it still shows up in
     * index() as something the company can reconnect.
     */
    public function disconnect(Request $request, GpsConnection $connection): JsonResponse
    {
        $company = $request->user()->transporterCompany;
        abort_unless($connection->transporter_company_id === $company->id, 404);

        DB::transaction(function () use ($connection) {
            $connection->trucks()->update(['gps_status' => 'not_connected']);
            $connection->update(['status' => 'disconnected']);
        });

        return response()->json(['message' => 'GPS disconnected.']);
    }

    private function extractPlate(string $unitName): string
    {
        // See DeviceNameParser's own docblock for the "<PLATE> <driver
        // name>" convention this splits on — let the company correct a
        // wrongly-parsed plate via "Add details" if a device was named
        // differently.
        return DeviceNameParser::parse($unitName)['plate'];
    }

    /**
     * Auto-suggests a truck for a unit by loose plate-text overlap
     * (AppFlow §2.3: "plate number pre-matched where it lines up") —
     * never authoritative, just a starting point the company confirms or
     * overrides before import() actually links anything.
     *
     * @param  Collection<int, Truck>  $trucks
     */
    private function suggestTruckMatch(GpsUnit $unit, Collection $trucks): ?Truck
    {
        $normalizedName = $this->normalizePlate($unit->name);

        return $trucks->first(function (Truck $truck) use ($normalizedName) {
            $normalizedPlate = $this->normalizePlate($truck->registration_number);

            return $normalizedPlate !== '' && str_contains($normalizedName, $normalizedPlate);
        });
    }

    private function normalizePlate(string $value): string
    {
        return strtoupper(preg_replace('/[^A-Za-z0-9]/', '', $value));
    }
}
