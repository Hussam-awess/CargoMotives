<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ConnectGpsRequest extends FormRequest
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
            // Matches gps_connections' own DB-level enum exactly (which
            // additionally reserves 'utrack_africa'/'easytrack' for future
            // providers not built yet — rejected here until they are).
            'provider' => ['required', Rule::in(['wialon', 'traccar', 'tracksolid_pro'])],
            'access_token' => ['required', 'string', 'max:500'],
        ];
    }
}
