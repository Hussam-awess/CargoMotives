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
        ];
    }
}
