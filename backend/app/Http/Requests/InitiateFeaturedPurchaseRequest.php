<?php

namespace App\Http\Requests;

use App\Rules\TanzanianMobileNumber;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Shared by both Company and Customer Featured-purchase endpoints — the
 * price itself is never client-supplied (it's a fixed platform_settings
 * value, not something a request could tamper with), only the mobile
 * money details needed to push the charge.
 */
class InitiateFeaturedPurchaseRequest extends FormRequest
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
            'mobile_money_provider' => ['required', Rule::in(['mpesa', 'tigopesa', 'airtelmoney', 'other'])],
            'phone_number' => ['required', 'string', new TanzanianMobileNumber],
        ];
    }
}
