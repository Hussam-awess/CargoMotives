<?php

namespace App\Http\Resources;

use App\Models\Bid;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Bid
 *
 * The `company` block is the trust profile shown on every bid (PRD §7.3):
 * "ABC Logistics ✓ · 28 trucks · Live GPS Available · ⭐4.8". The
 * checkmark is always true here — only an approved, good-standing company
 * can place a bid in the first place (BidController), so there's no
 * "unverified bid" state to represent.
 */
class BidResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'job_id' => $this->job_id,
            'price' => (float) $this->price,
            'estimated_pickup_time' => $this->estimated_pickup_time?->toIso8601String(),
            'note' => $this->note,
            'status' => $this->status,
            'is_priority' => $this->is_priority,
            // A one-tap return-load match (CompanyJobController::
            // claimReturnLoad()), not a competitive price bid — the client
            // renders this distinctly ("return load match" rather than a
            // normal bid card), though accepting it still goes through the
            // exact same BidController::accept() flow.
            'is_return_load_claim' => $this->is_return_load_claim,
            // Multi-Company Split Awards epic: how many trucks this bid
            // covers — 1 for an ordinary bid, indistinguishable from every
            // bid placed before this field existed.
            'trucks_offered' => $this->trucks_offered,
            'company' => [
                'id' => $this->company->id,
                'name' => $this->company->company_name,
                'verified' => true,
                'truck_count' => $this->company->verifiedTruckCount(),
                'gps_available' => $this->company->hasAnyGpsConnectedTruck(),
                'rating' => $this->company->average_rating !== null ? (float) $this->company->average_rating : null,
                'rating_count' => $this->company->rating_count,
            ],
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
