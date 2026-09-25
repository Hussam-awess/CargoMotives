<?php

namespace App\Http\Resources;

use App\Models\Job;
use App\Models\JobReview;
use App\Models\TransporterCompany;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A transporter company's public profile (Phase: public profiles) —
 * deliberately thinner than CompanyResource (the "my own company" shape,
 * which includes registration_number/tin/rep national ID/raw documents):
 * no contact details (business phone/email stay private — contact is
 * always via the in-app Message feature), no follow field (only a
 * customer can be followed).
 *
 * cancelled_jobs_count is deliberately omitted: only a customer can
 * currently cancel a job (JobController::cancel(), customer-only, only
 * while still 'open') — there is no real "transporter cancelled" action
 * in this app to count, so showing a count here would be inventing a
 * signal with nothing real behind it.
 *
 * @mixin TransporterCompany
 */
class CompanyProfileResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'company_name' => $this->company_name,
            'logo_url' => $this->logo_url ? app(DocumentStorage::class)->signedUrl($this->logo_url) : null,
            // A company's own logo (above) is optional at verification
            // time — most don't bother. Falling all the way back to an
            // initial-letter avatar when the owner DID upload a personal
            // photo would hide a real picture a customer could otherwise
            // see, so the owner's own avatar is exposed as a second choice
            // before that final fallback.
            'owner_avatar_url' => $this->owner?->avatar_url ? app(DocumentStorage::class)->signedUrl($this->owner->avatar_url) : null,
            'verified' => $this->verification_status === 'approved',
            // Cargo Motives Plus badge — distinct from `verified` above
            // (a real admin-reviewed approval): this is a paid tier, shown
            // here the same way it already is in-app (e.g. on this
            // company's own bids).
            'is_featured' => (bool) $this->is_featured,
            'location' => $this->physical_address,
            // Null on a company that hasn't dropped a pin yet — the public
            // profile falls back to the plain address text above.
            'location_lat' => $this->physical_lat,
            'location_lng' => $this->physical_lng,
            'member_since' => $this->created_at?->toIso8601String(),
            'average_rating' => $this->average_rating !== null ? (float) $this->average_rating : null,
            'rating_count' => (int) $this->rating_count,
            'completed_jobs_count' => Job::where('assigned_company_id', $this->id)->where('status', 'completed')->count(),
            'fleet_size' => $this->verifiedTruckCount(),
            'gps_available' => $this->hasAnyGpsConnectedTruck(),
            'recent_completed_jobs' => Job::recentCompletedSummariesFor('assigned_company_id', $this->id),
            'recent_reviews' => PublicReviewResource::collection(
                JobReview::where('ratee_company_id', $this->id)->latest('created_at')->limit(3)->get()
            ),
        ];
    }
}
