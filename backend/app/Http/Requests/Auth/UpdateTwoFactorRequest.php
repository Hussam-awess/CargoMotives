<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Both directions need the current password: turning 2FA off is the
 * dangerous one (a hijacked session could otherwise quietly strip it),
 * and turning it on shouldn't be something a borrowed phone can do to
 * lock its owner out either.
 */
class UpdateTwoFactorRequest extends FormRequest
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
            'enabled' => ['required', 'boolean'],
            'current_password' => ['required', 'string'],
        ];
    }
}
