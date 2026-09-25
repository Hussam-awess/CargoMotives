<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Truck registration (AppFlow §2.2): vehicle info + documents, submitted as
 * one request. Used both to register a new truck and to edit an existing
 * one — see rules() for why the documents aren't required in the second
 * case, and for the "locked" branch that limits an already-real truck's
 * edits to just capacity/type/photos.
 */
class SubmitTruckRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        // Once a truck has real details on file (anything other than a
        // bare GPS-imported placeholder — see Truck::is_gps_imported and
        // TruckController::save()'s own docblock), only capacity and type
        // stay editable: registration number, make/model, and documents
        // describe a specific physical vehicle and shouldn't casually
        // change after the fact. A fresh create, or completing a bare
        // GPS import for the first time, is exactly the "adding details"
        // step this lock kicks in *after* — so neither is locked here.
        $truck = $this->route('truck');
        $locked = $truck !== null && ! $truck->is_gps_imported;

        if ($locked) {
            return [
                'capacity_tons' => ['required', 'numeric', 'min:0.1', 'max:999'],
                'vehicle_type' => ['required', 'string', 'max:100'],
                // Photos are the one document-ish field exempt from the
                // lock above: they're just a visual reference, not a legal
                // identity document like the registration card/insurance/
                // roadworthiness permit, so a company can still refresh
                // them (a repaint, a better angle, an extra photo) without
                // that counting as "changing the vehicle." Optional here —
                // submitting a locked edit for capacity/type alone doesn't
                // require touching photos at all.
                'photos' => ['nullable', 'array', 'max:5'],
                'photos.*' => ['file', 'image', 'max:10240'],
            ];
        }

        // "Required unless this truck already has one on file." Editing
        // keeps existing documents, so correcting a capacity or a plate
        // typo doesn't mean re-uploading an insurance PDF — but a truck
        // that genuinely has no documents yet (a bare GPS import being
        // completed) still has to supply them.
        $ruleFor = fn (string $key) => filled(data_get($truck?->documents, $key)) ? 'sometimes' : 'required';

        return [
            'registration_number' => ['required', 'string', 'max:50'],
            'make_model' => ['required', 'string', 'max:255'],
            'vehicle_type' => ['required', 'string', 'max:100'],
            'capacity_tons' => ['required', 'numeric', 'min:0.1', 'max:999'],

            'photos' => [$ruleFor('photos'), 'array', 'min:1', 'max:5'],
            'photos.*' => ['file', 'image', 'max:10240'],
            'registration_card' => [$ruleFor('registration_card'), 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
            'insurance' => [$ruleFor('insurance'), 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
            // "as applicable" (TRD §7.2) — not every vehicle type needs one.
            'roadworthiness_permit' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
        ];
    }
}
