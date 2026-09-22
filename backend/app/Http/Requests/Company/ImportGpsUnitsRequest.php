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
            // Exactly one of truck_id (match to an existing truck) or
            // create_new (add this unit as a brand-new truck) applies per
            // entry — enforced in the controller rather than here, since
            // Laravel's wildcard conditional rules (required_if/
            // required_without against a sibling `matches.*.*` field) are
            // easy to get subtly wrong; a plain per-item check next to the
            // creation logic itself is clearer and just as safe.
            'matches.*.truck_id' => ['nullable', 'integer'],
            'matches.*.create_new' => ['sometimes', 'boolean'],
            'matches.*.unit_name' => ['nullable', 'string'],
        ];
    }
}
