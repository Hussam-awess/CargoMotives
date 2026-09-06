<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;

class ImportGpsUnitsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Controller-level company-ownership checks do the real authorization.
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'matches' => ['required', 'array', 'min:1'],
            'matches.*.unit_id' => ['required', 'string'],
            'matches.*.truck_id' => ['required', 'integer'],
        ];
    }
}
