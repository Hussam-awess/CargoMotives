<?php

namespace App\Http\Resources;

use App\Models\Job;
use App\Models\JobReview;
use App\Models\User;
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
            // Bulk Cargo epic: how many trucks this job needs — 1 for an
            // ordinary job.
            'trucks_needed' => $this->trucks_needed,
            'approx_weight_tons' => $this->approx_weight_tons !== null ? (float) $this->approx_weight_tons : null,
            'cargo_description' => $this->cargo_description,
            'preferred_pickup_window_start' => $this->preferred_pickup_window_start?->toIso8601String(),
            'preferred_pickup_window_end' => $this->preferred_pickup_window_end?->toIso8601String(),
            'customer_notes' => $this->customer_notes,
            // Bidding Deadline epic: bidding_closed is computed (never
            // stored) — the client renders the derived state rather than
            // doing its own date math against a value that could be skewed
            // by device clock drift. Null for every job with no deadline
            // set (every job posted before this feature, or one that opted
            // out — see PostJobRequest, currently always required for new
            // jobs, but old jobs stay null forever).
            'bidding_expires_at' => $this->bidding_expires_at?->toIso8601String(),
            'bidding_closed' => $this->when($this->bidding_expires_at !== null, fn () => $this->isBiddingClosed()),
            // The customer's own stated asking price — shown to a
            // transporter company deciding what to bid, distinct from
            // `agreed_price` (only ever set once a bid is accepted).
            // Optional: never fabricated when the customer didn't give one.
            'budget_price' => $this->budget_price !== null ? (float) $this->budget_price : null,
            // A Customer's optional business identity (Phase 11) — shown
            // to companies bidding on the job, not just the customer
            // themselves, per the product decision behind this field
            // (see users.company_name's migration comment).
            // Only needed by the Company side, to let a viewer follow/
            // unfollow this job's customer (Phase: Follow system) — same
            // whenLoaded gate as the other customer_* fields below.
            'customer_id' => $this->whenLoaded('customer', fn () => $this->customer_id),
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
            // The real moment this job was marked completed
            // (JobController::confirmDelivery()) — never the scheduled
            // preferred_pickup_window_start/end above.
            'completed_at' => $this->completed_at?->toIso8601String(),
            // Lets the viewer open the assigned company's public profile
            // (Phase: public profiles) — same whenLoaded gate as the name
            // below, since both come from the same eager-loaded relation.
            'assigned_company_id' => $this->whenLoaded('assignedCompany', fn () => $this->assignedCompany?->id),
            'assigned_company_name' => $this->whenLoaded('assignedCompany', fn () => $this->assignedCompany?->company_name),
            'assigned_truck_registration' => $this->whenLoaded('assignedTruck', fn () => $this->assignedTruck?->registration_number),
            'assigned_driver_name' => $this->whenLoaded('assignedDriver', fn () => $this->assignedDriver?->full_name),
            // Bulk Cargo epic: the full truck+driver roster. For an
            // ordinary job (trucks_needed <= 1) this is just the single
            // assignedTruck/assignedDriver pair, so the app can render one
            // consistent "fleet" list regardless of job size. Deliberately
            // excludes any Multi-Company Split Awards epic roster rows
            // (job_award_id set) — those belong to a specific award's own
            // assigned_fleet inside `awards` below, never mixed into this
            // job-level list.
            'assigned_fleet' => $this->when(
                $this->relationLoaded('truckAssignments') || $this->relationLoaded('assignedTruck'),
                fn () => $this->assignedFleet(),
            ),
            'assigned_trucks_count' => $this->when(isset($this->assigned_trucks_count), fn () => (int) $this->assigned_trucks_count),
            // Multi-Company Split Awards epic: how many trucks are still
            // uncovered on this job — only present on the Company-side
            // queries that select it. Equal to trucks_needed when no
            // awards exist yet.
            'remaining_trucks_needed' => $this->when(isset($this->remaining_trucks_needed), fn () => (int) $this->remaining_trucks_needed),
            // Multi-Company Split Awards epic: one entry per company that
            // ended up covering only part of trucks_needed — empty for
            // every ordinary job and for a bulk job fully covered by a
            // single company's bid (see JobAward's own docblock for why).
            'awards' => JobAwardResource::collection($this->whenLoaded('awards')),
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
                    'speed_kmh' => $this->assignedTruck->last_known_speed_kmh !== null ? (float) $this->assignedTruck->last_known_speed_kmh : null,
                    'recorded_at' => $this->assignedTruck->last_known_at->toIso8601String(),
                ];
            }),
            'bids_count' => $this->when(isset($this->bids_count), fn () => (int) $this->bids_count),
            // Cargo Motives Plus benefit: how many distinct transporter
            // companies have opened this job (JobView, recorded by
            // CompanyJobController::show()) — only present on the
            // customer's own queries (JobController::index()/show(), the
            // only ones that select it via withCount('jobViews')). The
            // mobile app decides whether to render it, gated on the
            // *viewing customer's own* is_featured status (already known
            // from their own profile) — same "expose the count, let the
            // client gate the display" pattern as customer_completed_jobs_count.
            'job_views_count' => $this->when(isset($this->job_views_count), fn () => (int) $this->job_views_count),
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
            // Whether the viewing transporter company already follows this
            // job's customer (Phase: Follow system) — only present on the
            // Company-side job queries that select it (CompanyJobController).
            'is_following_customer' => $this->when(
                isset($this->is_following_customer),
                fn () => (bool) $this->is_following_customer,
            ),
            // Bulk Cargo epic, corrected by the Multi-Company Split Awards
            // epic: whether the viewing company has at least one verified
            // truck AND the job still has remaining (not fully awarded)
            // capacity — only present on the Company-side queries that
            // select it (CompanyJobController). The job stays visible
            // either way; this only decides whether the bid form or a
            // "fleet too small"/"fully covered" message renders.
            // BidController::store() is the real, enforced gate.
            'is_eligible' => $this->when(
                isset($this->is_eligible),
                fn () => (bool) $this->is_eligible,
            ),
            // Two-way ratings (Phase: ratings) — only meaningful once a job
            // is 'completed', and only for the two participants (everyone
            // else, e.g. a company that just lost the bid, sees neither).
            // rated_by_viewer stays true forever once submitted — a review
            // is never editable.
            'rated_by_viewer' => $this->when(
                $this->status === 'completed' && $request->user() !== null,
                fn () => $this->hasViewerRated($request),
            ),
            'reviewable' => $this->when(
                $this->status === 'completed' && $request->user() !== null,
                fn () => $this->isViewerAParticipant($request->user()) && ! $this->hasViewerRated($request),
            ),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function assignedFleet(): array
    {
        if ($this->trucks_needed <= 1) {
            return $this->assignedTruck === null ? [] : [[
                'truck_id' => $this->assignedTruck->id,
                'registration_number' => $this->assignedTruck->registration_number,
                'driver_name' => $this->assignedDriver?->full_name,
            ]];
        }

        return $this->truckAssignments
            ->whereNull('job_award_id')
            ->map(fn ($assignment) => [
                'truck_id' => $assignment->truck_id,
                'registration_number' => $assignment->truck?->registration_number,
                'driver_name' => $assignment->driver?->full_name,
            ])->values()->all();
    }

    private function hasViewerRated(Request $request): bool
    {
        return JobReview::where('job_id', $this->id)->where('rater_user_id', $request->user()->id)->exists();
    }

    private function isViewerAParticipant(User $user): bool
    {
        // Multi-Company Split Awards epic: once a job has 2+ awards there
        // is no single company to rate/be rated by — assigned_company_id
        // stays null for exactly that case (see JobAward's docblock), so
        // this doubles as the "ratings are deferred for split jobs" gate.
        if ($this->assigned_company_id === null) {
            return false;
        }

        return $this->customer_id === $user->id || $this->assignedCompany?->owner_user_id === $user->id;
    }
}
