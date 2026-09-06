<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Driver roster entry (AppFlow §2.2): "add a driver with name + phone
 * (+ optional license photo)". No verification workflow — see the
 * drivers migration's note on why.
 */
class SaveDriverRequest extends FormRequest
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
            'full_name' => ['required', 'string', 'max:255'],
            'phone_number' => ['required', 'string', 'max:20'],
            'license_number' => ['nullable', 'string', 'max:100'],
            'license_photo' => ['nullable', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
        ];
    }
}
