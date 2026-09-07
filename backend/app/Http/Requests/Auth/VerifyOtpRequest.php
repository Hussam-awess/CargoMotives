<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class VerifyOtpRequest extends FormRequest
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
            'code' => ['required', 'string', 'digits:'.config('otp.code_length')],
            // Collected at this same step now (Phase 11's "Step 1 —
            // Account authentication"), not deferred — a transporter_
            // company account's full_name/email used to stay null until
            // Phase 2's verification flow set rep_full_name instead.
            'full_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255'],
        ];
    }
}
