<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\SaveDriverRequest;
use App\Http\Resources\DriverResource;
use App\Models\Driver;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Services\Auth\PhoneNumberNormalizer;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;

/**
 * The driver roster (AppFlow §2.2). No verification workflow — see the
 * drivers migration's note on why.
 */
class DriverController extends Controller
{
    public function __construct(private readonly DocumentStorage $documents) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return DriverResource::collection(
            $request->user()->transporterCompany->drivers()->latest()->get()
        );
    }

    public function store(SaveDriverRequest $request): DriverResource
    {
        return new DriverResource($this->save($request, $request->user()->transporterCompany, null));
    }

    public function update(SaveDriverRequest $request, Driver $driver): DriverResource
    {
        abort_unless($driver->transporter_company_id === $request->user()->transporterCompany->id, 404);

        return new DriverResource($this->save($request, $request->user()->transporterCompany, $driver));
    }

    /**
     * A company may remove a driver only while idle — not currently
     * assigned to a job still in progress. Unlike Truck (a current_status
     * column kept in sync by JobAssignmentService), a driver has no such
     * column, so "on a trip" is derived directly from whether any job
     * still assigns them (mirrors Job::isGpsTrackable()'s own status list).
     * Soft delete: past jobs and driver links keep resolving this driver
     * via their own withTrashed() relations.
     */
    public function destroy(Request $request, Driver $driver): JsonResponse
    {
        abort_unless($driver->transporter_company_id === $request->user()->transporterCompany->id, 404);

        $onATrip = Job::where('assigned_driver_id', $driver->id)
            ->whereIn('status', ['assigned', 'en_route_pickup', 'picked_up', 'in_transit'])
            ->exists();

        if ($onATrip) {
            throw ValidationException::withMessages([
                'driver' => ['This driver is currently on a trip and cannot be removed.'],
            ]);
        }

        $driver->delete();

        return response()->json(['message' => 'Driver removed.']);
    }

    private function save(SaveDriverRequest $request, TransporterCompany $company, ?Driver $driver): Driver
    {
        $validated = $request->validated();

        try {
            $phone = PhoneNumberNormalizer::normalize($validated['phone_number']);
        } catch (InvalidArgumentException $e) {
            throw ValidationException::withMessages(['phone_number' => [$e->getMessage()]]);
        }

        $attributes = [
            'full_name' => $validated['full_name'],
            'phone_number' => $phone,
            'license_number' => $validated['license_number'] ?? null,
            'photo_url' => $request->hasFile('license_photo')
                ? $this->documents->store($request->file('license_photo'), 'drivers/licenses')
                : $driver?->photo_url,
        ];

        return $driver
            ? tap($driver)->update($attributes)
            : Driver::create([...$attributes, 'transporter_company_id' => $company->id]);
    }
}
