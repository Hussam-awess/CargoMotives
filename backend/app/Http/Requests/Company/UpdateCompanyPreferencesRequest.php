<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;

class UpdateCompanyPreferencesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Controller checks the company exists — this is a shape check only.
    }

    /**
     * All `sometimes` — a caller updates whichever one preference it's
     * touching (the toggle, the floor rate, or the currency picker) without
     * needing to resend the others.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'auto_decline_below_budget' => ['sometimes', 'boolean'],
            'floor_rate' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'display_currency' => ['sometimes', 'in:TZS,USD'],
            'accepting_loads' => ['sometimes', 'boolean'],
        ];
    }
}
