<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class SendSupportMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Any authenticated user may write into their own thread.
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'body' => ['required', 'string', 'max:2000'],
        ];
    }
}
