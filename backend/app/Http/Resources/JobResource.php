<?php

namespace App\Http\Resources;

use App\Models\Job;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Job
 */
class JobResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status,
            'pickup_address' => $this->pickup_address,
            // Only populated when the query went through
            // Job::scopeWithCoordinates() — see that scope's docblock.
            'pickup_lat' => isset($this->pickup_lat) ? (float) $this->pickup_lat : null,
            'pickup_lng' => isset($this->pickup_lng) ? (float) $this->pickup_lng : null,
            'dropoff_address' => $this->dropoff_address,
            'dropoff_lat' => isset($this->dropoff_lat) ? (float) $this->dropoff_lat : null,
            'dropoff_lng' => isset($this->dropoff_lng) ? (float) $this->dropoff_lng : null,
            'container_type' => $this->container_type,
            'container_size' => $this->container_size,
            'approx_weight_tons' => $this->approx_weight_tons !== null ? (float) $this->approx_weight_tons : null,
            'cargo_description' => $this->cargo_description,
            'preferred_pickup_window_start' => $this->preferred_pickup_window_start?->toIso8601String(),
            'preferred_pickup_window_end' => $this->preferred_pickup_window_end?->toIso8601String(),
            'customer_notes' => $this->customer_notes,
            'agreed_price' => $this->agreed_price !== null ? (float) $this->agreed_price : null,
            'currency' => $this->currency,
            'cancelled_reason' => $this->cancelled_reason,
            'assigned_company_name' => $this->whenLoaded('assignedCompany', fn () => $this->assignedCompany?->company_name),
            'bids_count' => $this->when(isset($this->bids_count), fn () => (int) $this->bids_count),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
