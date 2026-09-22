<?php

namespace App\Http\Requests\Auth;

use App\Rules\TanzanianMobileNumber;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class RegisterCustomerRequest extends FormRequest
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
            'full_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone_number' => ['required', 'string', new TanzanianMobileNumber],
            'password' => ['required', 'confirmed', Password::min(8)],
            // Optional business identity (PRD change, Phase 11): shown to
            // companies bidding on this customer's jobs — see JobResource.
            'company_name' => ['nullable', 'string', 'max:255'],
            'logo' => ['nullable', 'image', 'max:5120'],
            // A denomination choice for this customer's own future job
            // postings, settable at signup — see users.preferred_currency's
            // migration docblock. Defaults to 'TZS' when omitted, same as
            // every account created before this field existed.
            'preferred_currency' => ['nullable', 'in:TZS,USD'],
        ];
    }
}
