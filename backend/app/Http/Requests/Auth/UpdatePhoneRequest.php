<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Immediate, unverified phone-number update — only valid when phone_number
 * is NOT the caller's login credential (ProfileController guards this).
 * Shape-only validation, same reasoning as RequestPhoneChangeRequest:
 * normalization + the real uniqueness check happen in the controller.
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
            'phone_number' => ['required', 'string'],
        ];
    }
}
