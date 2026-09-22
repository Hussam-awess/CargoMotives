<?php

namespace App\Http\Requests\Auth;

use App\Rules\TanzanianMobileNumber;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Immediate, unverified phone-number update — only valid when phone_number
 * is NOT the caller's login credential (ProfileController guards this).
 * The real uniqueness check happens in the controller (normalization is
 * now a no-op given TanzanianMobileNumber already pins the input shape).
 */
class UpdatePhoneRequest extends FormRequest
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
        ];
    }
}
