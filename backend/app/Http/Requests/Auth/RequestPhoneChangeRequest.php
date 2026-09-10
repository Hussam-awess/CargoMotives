<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class RequestPhoneChangeRequest extends FormRequest
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
            // Shape only — normalization + the real (post-normalization)
            // uniqueness check happens in the controller, same reasoning as
            // CustomerAuthController::register(): a raw unique:users rule
            // here can't catch two differently-formatted phone numbers that
            // normalize to the same value.
            'new_phone' => ['required', 'string'],
        ];
    }
}
