<?php

namespace App\Http\Requests\Reviews;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Category-rating keys differ by rating direction (customer rating a
 * transporter vs. transporter rating a customer) — resolved here from the
 * route's {job} + the caller's own id, same "which side is this" check
 * JobReviewController itself makes, rather than trusting a client-supplied
 * direction field.
 */
class StoreJobReviewRequest extends FormRequest
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
        $job = $this->route('job');
        $isCustomerRating = $job !== null && $job->customer_id === $this->user()?->id;
        $allowedKeys = $isCustomerRating
            ? ['punctuality', 'vehicle_condition', 'professionalism']
            : ['communication', 'cargo_accuracy', 'payment_promptness'];

        return [
            'rating' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:1000'],
            'category_ratings' => [
                'nullable',
                'array',
                function ($attribute, $value, $fail) use ($allowedKeys) {
                    if (array_diff(array_keys($value), $allowedKeys) !== []) {
                        $fail('Unexpected category rating key for this direction.');
                    }
                },
            ],
            'category_ratings.*' => ['integer', 'between:1,5'],
        ];
    }
}
