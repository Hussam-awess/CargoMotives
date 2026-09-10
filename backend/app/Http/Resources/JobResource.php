<?php

namespace App\Http\Resources;

use App\Models\Job;
use App\Services\Documents\DocumentStorage;
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
            // A Customer's optional business identity (Phase 11) — shown
            // to companies bidding on the job, not just the customer
            // themselves, per the product decision behind this field
            // (see users.company_name's migration comment).
            'customer_name' => $this->whenLoaded('customer', fn () => $this->customer->full_name),
            'customer_company_name' => $this->whenLoaded('customer', fn () => $this->customer->company_name),
            'customer_company_logo_url' => $this->whenLoaded('customer', function () {
                if (! $this->customer->company_logo_url) {
                    return null;
                }

                return app(DocumentStorage::class)->signedUrl($this->customer->company_logo_url);
            }),
            'agreed_price' => $this->agreed_price !== null ? (float) $this->agreed_price : null,
            'currency' => $this->currency,
            'cancelled_reason' => $this->cancelled_reason,
            'assigned_company_name' => $this->whenLoaded('assignedCompany', fn () => $this->assignedCompany?->company_name),
            'assigned_truck_registration' => $this->whenLoaded('assignedTruck', fn () => $this->assignedTruck?->registration_number),
            'assigned_driver_name' => $this->whenLoaded('assignedDriver', fn () => $this->assignedDriver?->full_name),
            'proof_of_delivery' => $this->whenLoaded('proofOfDelivery', fn () => $this->proofOfDelivery ? new ProofOfDeliveryResource($this->proofOfDelivery) : null),
            // Phase 6 (TRD §5.3): the frontend picks one of three states
            // from these two fields alone — no GPS connected at all
            // (gps_tracking_active=false), connected and healthy ('ok',
            // with a starting position below to show before the first
            // live WebSocket update arrives), or connected but quiet
            // ('lost'). Never a fourth ambiguous state.
            'gps_tracking_active' => (bool) $this->gps_tracking_active,
            'gps_signal_status' => $this->gps_signal_status,
            'last_known_location' => $this->whenLoaded('assignedTruck', function () {
                if (! $this->gps_tracking_active || $this->assignedTruck?->last_known_at === null) {
                    return null;
                }

                return [
                    'lat' => (float) $this->assignedTruck->last_known_lat,
                    'lng' => (float) $this->assignedTruck->last_known_lng,
                    'heading' => $this->assignedTruck->last_known_heading !== null ? (float) $this->assignedTruck->last_known_heading : null,
                    'recorded_at' => $this->assignedTruck->last_known_at->toIso8601String(),
                ];
            }),
            'bids_count' => $this->when(isset($this->bids_count), fn () => (int) $this->bids_count),
            // Company Plus benefit (Phase 10.19): the posting customer's
            // real completed-shipment count, a trust signal shown to a
            // Featured company browsing Open Jobs — only present on
            // CompanyJobController::open()'s query, which is the only
            // place that selects it; the UI decides whether to display it
            // (gated to Featured viewers), same pattern as is_priority.
            'customer_completed_jobs_count' => $this->when(
                isset($this->customer_completed_jobs_count),
                fn () => (int) $this->customer_completed_jobs_count,
            ),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
