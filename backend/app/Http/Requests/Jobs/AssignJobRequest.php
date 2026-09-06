<?php

namespace App\Http\Requests\Jobs;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class AssignJobRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Controller-level company-ownership checks do the real authorization.
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $companyId = $this->user()->transporterCompany->id;

        return [
            'truck_id' => [
                'required',
                'integer',
                Rule::exists('trucks', 'id')->where('transporter_company_id', $companyId),
            ],
            'driver_id' => [
                'required',
                'integer',
                Rule::exists('drivers', 'id')->where('transporter_company_id', $companyId),
            ],
        ];
    }
}
