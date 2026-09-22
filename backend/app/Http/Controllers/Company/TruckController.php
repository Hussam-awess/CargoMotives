<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\SubmitTruckRequest;
use App\Http\Resources\TruckResource;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

/**
 * Truck registration (AppFlow §2.2). A company can register any number of
 * trucks (PRD §7.2) and each is usable immediately — the Admin review step
 * trucks used to go through was removed (see Truck::$attributes). Company
 * verification is unaffected: a company still has to be approved before it
 * can reach any of this.
 */
class TruckController extends Controller
{
    public function __construct(private readonly DocumentStorage $documents) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return TruckResource::collection(
            $request->user()->transporterCompany->trucks()->with('gpsConnection')->latest()->get()
        );
    }

    public function show(Request $request, Truck $truck): TruckResource
    {
        $this->authorizeOwnership($request, $truck);

        return new TruckResource($truck);
    }

    /**
     * The fleet map (AppFlow §2.7) — just the company's own GPS-connected
     * trucks (TruckResource already exposes last_known_* for every truck
     * since Phase 6; this just narrows the list to ones that actually
     * have a position worth showing). No longer Featured-only — every
     * transporter can see their own fleet's live positions; Plus still
     * gates unlimited quotas, badges, and the priority job-feed sort
     * elsewhere.
     */
    public function map(Request $request): AnonymousResourceCollection
    {
        $company = $request->user()->transporterCompany;

        return TruckResource::collection(
            $company->trucks()->where('gps_status', 'connected')->get()
        );
    }

    public function store(SubmitTruckRequest $request): TruckResource
    {
        return new TruckResource($this->save($request, $request->user()->transporterCompany, null));
    }

    public function update(SubmitTruckRequest $request, Truck $truck): TruckResource
    {
        $this->authorizeOwnership($request, $truck);

        return new TruckResource($this->save($request, $request->user()->transporterCompany, $truck));
    }

    /**
     * A company may remove a truck only while it's idle — not out on a
     * job (PRD: fleet changes must never disrupt work in progress) — and
     * only once it's no longer linked to a live GPS device, so a device
     * doesn't keep reporting positions for a truck that's just vanished.
     * Soft delete: past jobs keep resolving this truck's registration/GPS
     * history via Job::assignedTruck()'s own withTrashed().
     */
    public function destroy(Request $request, Truck $truck): JsonResponse
    {
        $this->authorizeOwnership($request, $truck);

        if ($truck->current_status !== 'idle') {
            throw ValidationException::withMessages([
                'truck' => ['This truck is currently on a job and cannot be removed.'],
            ]);
        }

        if ($truck->gps_status !== 'not_connected') {
            throw ValidationException::withMessages([
                'truck' => ['Disconnect this truck from GPS before removing it.'],
            ]);
        }

        $truck->delete();

        return response()->json(['message' => 'Truck removed.']);
    }

    /**
     * A per-truck GPS disconnect — distinct from
     * GpsConnectionController::disconnect(), which tears down an entire
     * provider connection and every truck linked to it. This is for the
     * narrower case of one truck's device being removed or reassigned
     * while the rest of the fleet's GPS keeps working, and is also the
     * only way to unblock deleting a GPS-connected truck (see destroy()).
     *
     * Clears gps_connection_id/gps_unit_id, not just gps_status:
     * PollGpsPositionsJob selects which trucks to poll by those IDs, not
     * by gps_status, so leaving them in place would mean the next poll
     * cycle keeps reporting positions for a truck the user just
     * disconnected.
     */
    public function disconnectGps(Request $request, Truck $truck): TruckResource
    {
        $this->authorizeOwnership($request, $truck);

        $truck->update([
            'gps_status' => 'not_connected',
            'gps_connection_id' => null,
            'gps_unit_id' => null,
        ]);

        return new TruckResource($truck);
    }

    private function authorizeOwnership(Request $request, Truck $truck): void
    {
        abort_unless($truck->transporter_company_id === $request->user()->transporterCompany->id, 404);
    }

    private function save(SubmitTruckRequest $request, TransporterCompany $company, ?Truck $truck): Truck
    {
        $validated = $request->validated();

        // Mirrors SubmitTruckRequest's own "locked" check — hasFile()
        // doesn't care about validation rules, so a locked request's
        // document fields (not required, but not forbidden either) have
        // to be explicitly skipped here too, or a stray file attach could
        // sneak a document change past the lock.
        $locked = $truck !== null && ! $truck->is_gps_imported;

        // Start from whatever this truck already has, so editing only the
        // vehicle details (a corrected capacity, a plate typo) keeps the
        // existing documents instead of wiping them. Each one is replaced
        // only when a new file is actually attached. A new truck starts
        // empty and SubmitTruckRequest requires all three up front.
        $documents = $truck?->documents ?? [];

        if (! $locked) {
            if ($request->hasFile('photos')) {
                $documents['photos'] = collect($request->file('photos'))
                    ->map(fn ($photo) => $this->documents->store($photo, 'trucks/photos'))
                    ->all();
            }
            foreach (['registration_card', 'insurance', 'roadworthiness_permit'] as $document) {
                if ($request->hasFile($document)) {
                    $documents[$document] = $this->documents->store($request->file($document), 'trucks/documents');
                }
            }
        }

        $attributes = [
            ...collect($validated)->except(['photos', 'registration_card', 'insurance', 'roadworthiness_permit'])->all(),
            'documents' => $documents,
            // Truck review was removed — see Truck::$attributes. A truck is
            // usable the moment it's registered.
            'verification_status' => 'approved',
            'verification_rejected_reason' => null,
            // Submitting real details through this form is exactly what
            // "completing" a GPS import means — the truck stops being a
            // bare GPS shell and becomes a fully registered one.
            'is_gps_imported' => false,
        ];

        return $truck
            ? tap($truck)->update($attributes)
            : Truck::create([...$attributes, 'transporter_company_id' => $company->id]);
    }
}
