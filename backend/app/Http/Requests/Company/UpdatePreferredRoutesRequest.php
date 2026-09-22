<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;

class UpdatePreferredRoutesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Controller checks is_featured — this is a shape check only.
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'routes' => ['present', 'array', 'max:10'],
            'routes.*.origin' => ['required', 'string', 'max:255'],
            'routes.*.destination' => ['required', 'string', 'max:255'],
            // The company's base/return-to region (return-load matching,
            // Cargo Motives Plus benefit) — a plain free-text region name,
            // same text-match convention as the routes above, not a
            // coordinate. Optional: a company that hasn't set one just
            // sees return-load suggestions ranked by proximity alone.
            'home_region' => ['nullable', 'string', 'max:255'],
        ];
    }
}
