<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Immediate, unverified email update — only valid when email is NOT the
 * caller's login credential (ProfileController guards this). Uniqueness is
 * checked in the controller (excluding the caller's own row).
 */
class UpdateEmailRequest extends FormRequest
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
            'email' => ['required', 'email', 'max:255'],
        ];
    }
}
