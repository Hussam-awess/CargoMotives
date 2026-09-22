<?php

namespace App\Http\Requests\Auth;

use App\Rules\TanzanianMobileNumber;
use Illuminate\Foundation\Http\FormRequest;

class CompanyLoginRequest extends FormRequest
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
            'password' => ['required', 'string'],
        ];
    }
}
