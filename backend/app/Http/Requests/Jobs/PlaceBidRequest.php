<?php

namespace App\Http\Requests\Jobs;

use App\Models\JobAward;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Place Bid (AppFlow §2.4): price, ETA, note, and (Multi-Company Split
 * Awards epic) how many trucks this bid covers.
 */
class PlaceBidRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Defaults trucks_offered to 1 when omitted — an ordinary job's bid
     * form, and every client that predates this field, never needs to
     * think about it.
     */
    protected function prepareForValidation(): void
    {
        if (! $this->has('trucks_offered')) {
            $this->merge(['trucks_offered' => 1]);
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $job = $this->route('job');
        $remaining = $job->trucks_needed - JobAward::where('job_id', $job->id)->sum('trucks_offered');

        return [
            'price' => ['required', 'numeric', 'min:1000', 'max:999999999'],
            'trucks_offered' => ['required', 'integer', 'min:1', 'max:'.max($remaining, 1)],
            'estimated_pickup_time' => ['nullable', 'date', 'after_or_equal:now'],
            'note' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
