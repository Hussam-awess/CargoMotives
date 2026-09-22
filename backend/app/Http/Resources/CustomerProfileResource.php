<?php

namespace App\Http\Resources;

use App\Models\CustomerFollow;
use App\Models\Job;
use App\Models\JobReview;
use App\Models\User;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A customer's public profile (Phase: public profiles) — deliberately
 * thinner than UserResource (the "my own profile" shape, which includes
 * phone/email): no contact details, no verification badge (every customer
 * account is already OTP/email-verified just to exist, so a badge here
 * would be meaningless decoration — see CompanyProfileResource for a real
 * one), no location (no city field is ever collected from a customer at
 * signup today).
 *
 * @mixin User
 */
class CustomerProfileResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'full_name' => $this->full_name,
            'company_name' => $this->company_name,
            'company_logo_url' => $this->company_logo_url
                ? app(DocumentStorage::class)->signedUrl($this->company_logo_url)
                : null,
            // The customer's own personal photo (EditProfileScreen) —
            // distinct from company_logo_url above (an optional *business*
            // identity most customers never set up). A transporter viewing
            // this profile should see whichever picture actually exists,
            // not just fall back to an initial-letter avatar because the
            // business-only field happens to be null.
            'avatar_url' => $this->avatar_url ? app(DocumentStorage::class)->signedUrl($this->avatar_url) : null,
            // Cargo Motives Plus badge — a real, paid-for status (unlike
            // the verification badge this resource deliberately omits
            // above), so it's shown here same as it is in-app.
            'is_featured' => (bool) $this->is_featured,
            'member_since' => $this->created_at?->toIso8601String(),
            'average_rating' => $this->average_rating !== null ? (float) $this->average_rating : null,
            'rating_count' => (int) $this->rating_count,
            'completed_jobs_count' => Job::where('customer_id', $this->id)->where('status', 'completed')->count(),
            'cancelled_jobs_count' => Job::where('customer_id', $this->id)->where('status', 'cancelled')->count(),
            'recent_completed_jobs' => Job::recentCompletedSummariesFor('customer_id', $this->id),
            'recent_reviews' => PublicReviewResource::collection(
                JobReview::where('ratee_customer_id', $this->id)->latest('created_at')->limit(3)->get()
            ),
            // Only meaningful for a transporter viewer — a customer or
            // admin viewing another customer's profile can't follow them.
            'is_following' => $this->when(
                $request->user()?->account_type === 'transporter_company',
                fn () => CustomerFollow::where('transporter_company_id', $request->user()->transporterCompany?->id)
                    ->where('customer_id', $this->id)
                    ->exists(),
            ),
        ];
    }
}
