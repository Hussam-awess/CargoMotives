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
            // Only 'wialon' is a real integration yet (Phase 6) — Traccar/
            // Tracksolid Pro are rejected here rather than silently
            // accepted and doing nothing, per "don't build for the other
            // providers yet."
            'provider' => ['required', Rule::in(['wialon'])],
            'access_token' => ['required', 'string', 'max:500'],
        ];
    }
}
