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
            'account_type' => ['required', 'in:customer,transporter_company'],
            'code' => ['required', 'string', 'digits:'.config('otp.code_length')],
        ];
    }
}
