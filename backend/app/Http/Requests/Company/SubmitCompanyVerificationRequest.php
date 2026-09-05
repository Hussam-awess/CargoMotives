<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Validates the two-section verification form (AppFlow §1: Company Info,
 * then Representative Info with a selfie) submitted in one request —
 * matching the TRD's "single multi-step form" on the frontend, one POST on
 * the backend.
 */
class SubmitCompanyVerificationRequest extends FormRequest
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
            // Company info
            'company_name' => ['required', 'string', 'max:255'],
            'registration_number' => ['required', 'string', 'max:100'],
            'tin' => ['required', 'string', 'max:100'],
            'physical_address' => ['required', 'string', 'max:1000'],
            'company_phone' => ['required', 'string', 'max:20'],
            'company_email' => ['nullable', 'email', 'max:255'],
            'logo' => ['nullable', 'image', 'max:5120'],
            'business_license' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],

            // Representative info — phone is deliberately not collected
            // here; it's the already-OTP-verified owner account's own
            // phone_number (Phase 1), not a separate field.
            'rep_full_name' => ['required', 'string', 'max:255'],
            'rep_position' => ['required', 'string', 'max:255'],
            'rep_national_id_number' => ['required', 'string', 'max:50'],
            'rep_id_document' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
            'rep_selfie' => ['required', 'image', 'max:10240'],
        ];
    }
}
