<?php

namespace App\Http\Requests\Company;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class InitiateCommissionPaymentRequest extends FormRequest
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
        $company = $this->user()->transporterCompany;

        return [
            // Capped at the current balance — paying down more than is
            // owed isn't a flow the docs describe (AppFlow §2.6: "Pay via
            // Mobile Money button whenever the company wants to pay it
            // down"), and a balance of 0 correctly makes any amount here
            // invalid, since there is nothing to pay.
            'amount' => ['required', 'numeric', 'min:1', 'max:'.$company->outstanding_balance],
            'mobile_money_provider' => ['required', Rule::in(['mpesa', 'tigopesa', 'airtelmoney', 'other'])],
            'phone_number' => ['required', 'string', 'max:20'],
        ];
    }
}
