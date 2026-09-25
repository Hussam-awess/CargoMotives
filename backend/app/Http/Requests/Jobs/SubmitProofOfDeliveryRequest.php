<?php

namespace App\Http\Requests\Jobs;

use Illuminate\Foundation\Http\FormRequest;

class SubmitProofOfDeliveryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Controller checks the company owns this job/award.
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'photos' => ['required', 'array', 'min:1'],
            'photos.*' => ['required', 'file', 'mimes:jpg,jpeg,png,heic', 'max:10240'],
            'recipient_name' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'truck_id' => ['nullable', 'integer'],
        ];
    }
}
