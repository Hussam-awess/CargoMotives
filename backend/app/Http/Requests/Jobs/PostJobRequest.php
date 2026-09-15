<?php

namespace App\Http\Requests\Jobs;

use Illuminate\Foundation\Http\FormRequest;

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
            'approx_weight_tons' => ['nullable', 'numeric', 'min:0.1', 'max:999'],
            'cargo_description' => ['nullable', 'string', 'max:2000'],
            'budget_price' => ['nullable', 'numeric', 'min:0'],
            'preferred_pickup_window_start' => ['required', 'date', 'after_or_equal:now'],
            'preferred_pickup_window_end' => ['nullable', 'date', 'after:preferred_pickup_window_start'],
            'customer_notes' => ['nullable', 'string', 'max:2000'],
            'photos' => ['nullable', 'array', 'max:5'],
            'photos.*' => ['file', 'image', 'max:10240'],
        ];
    }
}
