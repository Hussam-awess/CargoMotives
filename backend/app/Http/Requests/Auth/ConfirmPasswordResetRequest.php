<?php

namespace App\Http\Requests\Auth;

use App\Rules\TanzanianMobileNumber;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class ConfirmPasswordResetRequest extends FormRequest
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
            'phone_number' => ['required', 'string', new TanzanianMobileNumber],
            'code' => ['required', 'string', 'digits:'.config('otp.code_length')],
            'password' => ['required', 'confirmed', Password::min(8)],
        ];
    }
}
