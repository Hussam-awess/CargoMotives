<?php

namespace App\Http\Requests\Auth;

use App\Rules\TanzanianMobileNumber;
use Illuminate\Foundation\Http\FormRequest;

class RequestPhoneChangeRequest extends FormRequest
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
            // Uniqueness (post-normalization, which is a no-op now that
            // TanzanianMobileNumber already pins the input shape) still
            // happens in the controller, same reasoning as
            // CustomerAuthController::register().
            'new_phone' => ['required', 'string', new TanzanianMobileNumber],
            // Proves the caller still controls the account before it can
            // start hijacking its own login credential — see
            // ProfileController::requestPhoneChange().
            'current_password' => ['required', 'string'],
        ];
    }
}
