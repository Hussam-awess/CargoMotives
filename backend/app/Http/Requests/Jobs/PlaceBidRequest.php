<?php

namespace App\Http\Requests\Jobs;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Place Bid (AppFlow §2.4): price, ETA, note.
 */
class PlaceBidRequest extends FormRequest
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
            'price' => ['required', 'numeric', 'min:1000', 'max:999999999'],
            'estimated_pickup_time' => ['nullable', 'date', 'after_or_equal:now'],
            'note' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
