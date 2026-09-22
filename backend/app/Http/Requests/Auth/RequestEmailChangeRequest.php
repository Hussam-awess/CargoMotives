<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RequestEmailChangeRequest extends FormRequest
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
            'new_email' => ['required', 'email', Rule::unique('users', 'email')->ignore($this->user()->id)],
            // Proves the caller still controls the account before it can
            // start hijacking its own login credential — see
            // ProfileController::requestEmailChange().
            'current_password' => ['required', 'string'],
        ];
    }
}
