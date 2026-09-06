<?php

namespace App\Http\Requests\DriverLink;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateJobStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // The token itself (checked by the controller) is the authorization.
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in(['en_route_pickup', 'picked_up', 'in_transit'])],
        ];
    }
}
