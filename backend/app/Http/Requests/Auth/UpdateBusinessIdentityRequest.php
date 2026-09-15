<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * A Customer's optional business identity (Phase 11) — company_name +
 * logo, the same fields collected at registration (RegisterCustomerRequest),
 * now editable afterward. Customer-only; ProfileController rejects any
 * other account_type.
 */
class UpdateBusinessIdentityRequest extends FormRequest
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
            'company_name' => ['nullable', 'string', 'max:255'],
            'logo' => ['nullable', 'image', 'max:5120'],
        ];
    }
}
