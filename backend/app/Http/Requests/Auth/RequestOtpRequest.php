<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class RequestOtpRequest extends FormRequest
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
            'phone_number' => ['required', 'string', 'max:20'],
            // Customer moved to email+password (CustomerAuthController,
            // Phase 11) — phone+SMS-OTP is Transporter Company only now.
            'account_type' => ['required', 'in:transporter_company'],
            // Collected here now, not at verify-time (design-import restyle,
            // matching the mockup's "Step 1 — Account" screen): stashed
            // pending, alongside the OTP code, until verifyOtp() succeeds —
            // see AuthController::requestOtp()'s docblock.
            'full_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
        ];
    }
}
