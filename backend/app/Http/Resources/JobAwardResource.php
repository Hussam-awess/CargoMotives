<?php

namespace App\Http\Resources;

use App\Models\JobAward;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One company's committed slice of a multi-company bulk job (Multi-Company
 * Split Awards epic) — see App\Models\JobAward's docblock. Deliberately
 * thin and self-contained (its own fleet/GPS/proof-of-delivery), the same
 * way JobResource is thin about the single-company case it mirrors.
 *
 * @mixin JobAward
 */
class JobAwardResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'company_id' => $this->transporter_company_id,
            'company_name' => $this->whenLoaded('company', fn () => $this->company?->company_name),
            'trucks_offered' => $this->trucks_offered,
            'agreed_price' => (float) $this->agreed_price,
            'status' => $this->status,
            'completed_at' => $this->completed_at?->toIso8601String(),
            'assigned_fleet' => $this->when(
                $this->relationLoaded('truckAssignments'),
                fn () => $this->truckAssignments->map(fn ($assignment) => [
                    'truck_id' => $assignment->truck_id,
                    'registration_number' => $assignment->truck?->registration_number,
                    'driver_name' => $assignment->driver?->full_name,
                ])->all(),
            ),
            'assigned_trucks_count' => $this->when($this->relationLoaded('truckAssignments'), fn () => $this->truckAssignments->count()),
            'gps_tracking_active' => (bool) $this->gps_tracking_active,
            'gps_signal_status' => $this->gps_signal_status,
            'last_known_location' => $this->when($this->relationLoaded('truckAssignments'), function () {
                $lead = $this->truckAssignments->firstWhere('is_lead', true);
                if (! $this->gps_tracking_active || $lead?->truck?->last_known_at === null) {
                    return null;
                }

                return [
                    'lat' => (float) $lead->truck->last_known_lat,
                    'lng' => (float) $lead->truck->last_known_lng,
                    'heading' => $lead->truck->last_known_heading !== null ? (float) $lead->truck->last_known_heading : null,
                    'speed_kmh' => $lead->truck->last_known_speed_kmh !== null ? (float) $lead->truck->last_known_speed_kmh : null,
                    'recorded_at' => $lead->truck->last_known_at->toIso8601String(),
                ];
            }),
            'proof_of_delivery' => $this->whenLoaded('proofOfDelivery', fn () => $this->proofOfDelivery ? new ProofOfDeliveryResource($this->proofOfDelivery) : null),
        ];
    }
}
