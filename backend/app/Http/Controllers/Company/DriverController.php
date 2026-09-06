<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\SaveDriverRequest;
use App\Http\Resources\DriverResource;
use App\Models\Driver;
use App\Models\TransporterCompany;
use App\Services\Auth\PhoneNumberNormalizer;
use App\Services\Documents\DocumentStorage;
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
