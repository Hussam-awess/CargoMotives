<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\SubmitTruckRequest;
use App\Http\Resources\TruckResource;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

/**
 * Truck registration (AppFlow §2.2). A company can register any number of
 * trucks (PRD §7.2), each verified independently — unlike company
 * verification, there's no 1:1 relationship here, so create/update are
 * separate actions scoped to a specific truck.
 */
class TruckController extends Controller
{
    public function __construct(private readonly DocumentStorage $documents) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        return TruckResource::collection(
            $request->user()->transporterCompany->trucks()->latest()->get()
        );
    }

    public function show(Request $request, Truck $truck): TruckResource
    {
        $this->authorizeOwnership($request, $truck);

        return new TruckResource($truck);
    }

    /**
     * The Featured "fleet map" (AppFlow §2.7) — just the company's own
     * GPS-connected trucks (TruckResource already exposes last_known_*
     * for every truck since Phase 6; this just narrows the list to ones
     * that actually have a position worth showing).
     */
    public function map(Request $request): AnonymousResourceCollection
    {
        $company = $request->user()->transporterCompany;
        abort_unless($company->is_featured, 403, 'The fleet map is a Featured-only feature.');

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

        if (! in_array($truck->verification_status, ['pending', 'rejected'], true)) {
            throw ValidationException::withMessages([
                'registration_number' => ['An approved truck cannot be edited here.'],
            ]);
        }

        return new TruckResource($this->save($request, $request->user()->transporterCompany, $truck));
    }

    private function authorizeOwnership(Request $request, Truck $truck): void
    {
        abort_unless($truck->transporter_company_id === $request->user()->transporterCompany->id, 404);
    }

    private function save(SubmitTruckRequest $request, TransporterCompany $company, ?Truck $truck): Truck
    {
        $validated = $request->validated();

        $documents = [
            'photos' => collect($request->file('photos'))
                ->map(fn ($photo) => $this->documents->store($photo, 'trucks/photos'))
                ->all(),
            'registration_card' => $this->documents->store($request->file('registration_card'), 'trucks/documents'),
            'insurance' => $this->documents->store($request->file('insurance'), 'trucks/documents'),
        ];
        if ($request->hasFile('roadworthiness_permit')) {
            $documents['roadworthiness_permit'] = $this->documents->store($request->file('roadworthiness_permit'), 'trucks/documents');
        }

        $attributes = [
            ...collect($validated)->except(['photos', 'registration_card', 'insurance', 'roadworthiness_permit'])->all(),
            'documents' => $documents,
            'verification_status' => 'pending',
            'verification_rejected_reason' => null,
        ];

        return $truck
            ? tap($truck)->update($attributes)
            : Truck::create([...$attributes, 'transporter_company_id' => $company->id]);
    }
}
