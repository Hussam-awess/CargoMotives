<?php

namespace App\Http\Requests\Auth;

use App\Rules\TanzanianMobileNumber;
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
            'phone_number' => ['required', 'string', new TanzanianMobileNumber],
            // Customer moved to email+password (CustomerAuthController,
            // Phase 11) — phone+SMS-OTP is Transporter Company only now.
            'account_type' => ['required', 'in:transporter_company'],
            'code' => ['required', 'string', 'digits:'.config('otp.code_length')],
            // full_name/email/password moved to RequestOtpRequest
            // (design-import restyle) — this step is code-only now,
            // matching the mockup's plain OTP screen. The account is
            // created from the pending cache entry stashed at request-time.
        ];
    }
}
