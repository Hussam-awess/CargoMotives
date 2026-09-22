<?php

namespace App\Http\Requests\Jobs;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * Post a Job (AppFlow §3.2): locations, container/cargo details, timing,
 * notes. Used for both creating a job and editing one (JobController only
 * allows editing while still 'open' — see that controller).
 */
class PostJobRequest extends FormRequest
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
            'pickup_address' => ['required', 'string', 'max:500'],
            'pickup_lat' => ['required', 'numeric', 'between:-90,90'],
            'pickup_lng' => ['required', 'numeric', 'between:-180,180'],
            'dropoff_address' => ['required', 'string', 'max:500'],
            'dropoff_lat' => ['required', 'numeric', 'between:-90,90'],
            'dropoff_lng' => ['required', 'numeric', 'between:-180,180'],
            'container_type' => ['required', 'string', 'max:100'],
            'container_size' => ['required', 'string', 'max:50'],
            // Bulk Cargo epic: how many trucks this job needs — 1 for an
            // ordinary job, keeping it indistinguishable from every job
            // posted before this field existed. 200 is a placeholder
            // ceiling, not a locked product decision.
            'trucks_needed' => ['required', 'integer', 'min:1', 'max:200'],
            'approx_weight_tons' => ['nullable', 'numeric', 'min:0.1', 'max:999'],
            'cargo_description' => ['nullable', 'string', 'max:2000'],
            // A denomination choice only — see the users.preferred_currency
            // migration's docblock. Defaults to the posting customer's own
            // preference when the client omits it, so an older client that
            // predates this field keeps posting in TZS exactly as before.
            'currency' => ['sometimes', 'in:TZS,USD'],
            // Required (was optional pre-launch) — every job now states a
            // budget so transporters have a real number to bid against.
            // The actual min/max floor/ceiling is currency-specific (see
            // withValidator below) — TZS and USD amounts differ by three
            // orders of magnitude for the same real-world price, so one
            // fixed bound can't sensibly cover both.
            'budget_price' => ['required', 'numeric'],
            'preferred_pickup_window_start' => ['required', 'date', 'after_or_equal:now'],
            'preferred_pickup_window_end' => ['nullable', 'date', 'after:preferred_pickup_window_start'],
            'customer_notes' => ['nullable', 'string', 'max:2000'],
            'photos' => ['nullable', 'array', 'max:5'],
            'photos.*' => ['file', 'image', 'max:10240'],
            // Bidding Deadline epic: required so every new job states one —
            // bounded to config('bidding.min_days'/'max_days') out from now,
            // and always before the truck should already be collecting.
            'bidding_expires_at' => ['required', 'date', 'after:now', 'before:preferred_pickup_window_start'],
        ];
    }

    /**
     * The min/max floor/ceiling per currency (Same order-of-magnitude
     * reasoning as PlaceBidRequest would need if bids ever also went
     * multi-currency — not done here since a bid is always denominated in
     * whatever currency its job already specified, never a separate
     * choice). Placeholder bounds, not exchange-rate-derived: this app has
     * no conversion system, so these are just "a sensible floor above
     * zero, a generous ceiling," not a real currency conversion of the
     * TZS figures.
     *
     * @var array<string, array{0: float, 1: float}>
     */
    private const BUDGET_BOUNDS = [
        'TZS' => [1000, 999999999],
        'USD' => [1, 500000],
    ];

    /**
     * @param  Validator  $validator
     */
    public function withValidator($validator): void
    {
        $validator->after(function (Validator $validator) {
            // Editing an existing job: currency can't actually change
            // (JobController::save() strips it), so the bounds check must
            // use the job's own real currency — never whatever the client
            // happens to submit — or a submitted mismatch could sneak a
            // budget_price past the wrong bounds entirely.
            $existingJob = $this->route('job');
            $submittedCurrency = $this->string('currency')->toString();
            $currency = $existingJob?->currency
                ?? ($submittedCurrency !== '' ? $submittedCurrency : ($this->user()?->preferred_currency ?? 'TZS'));
            [$min, $max] = self::BUDGET_BOUNDS[$currency] ?? self::BUDGET_BOUNDS['TZS'];
            $budget = $this->input('budget_price');

            if (is_numeric($budget) && ((float) $budget < $min || (float) $budget > $max)) {
                $validator->errors()->add('budget_price', "The budget must be between {$min} and {$max} {$currency}.");
            }

            $expiresAt = $this->date('bidding_expires_at');
            if ($expiresAt === null) {
                // The plain 'date'/'after'/'before' rules above already
                // caught this — nothing further to check against a value
                // that never parsed.
                return;
            }

            $minDays = (int) config('bidding.min_days', 1);
            $maxDays = (int) config('bidding.max_days', 7);

            if ($expiresAt->lt(now()->addDays($minDays))) {
                $validator->errors()->add('bidding_expires_at', "Bidding must stay open for at least {$minDays} day(s).");
            } elseif ($expiresAt->gt(now()->addDays($maxDays))) {
                $validator->errors()->add('bidding_expires_at', "Bidding can close at most {$maxDays} day(s) from now.");
            }
        });
    }
}
