<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Truck registration (AppFlow §2.2): vehicle info + documents, submitted as
 * one request. Used for both a new truck and resubmitting a rejected one.
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
        return [
            'registration_number' => ['required', 'string', 'max:50'],
            'make_model' => ['required', 'string', 'max:255'],
            'vehicle_type' => ['required', 'string', 'max:100'],
            'capacity_tons' => ['required', 'numeric', 'min:0.1', 'max:999'],

            'photos' => ['required', 'array', 'min:1', 'max:5'],
            'photos.*' => ['file', 'image', 'max:10240'],
            'registration_card' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
            'insurance' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
            // "as applicable" (TRD §7.2) — not every vehicle type needs one.
            'roadworthiness_permit' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
        ];
    }
}
