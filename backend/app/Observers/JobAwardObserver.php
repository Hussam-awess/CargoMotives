<?php

namespace App\Observers;

use App\Models\JobAward;
use App\Services\Notifications\NotificationService;

/**
 * The Multi-Company Split Awards epic's per-award equivalent of the two
 * status-driven notifications JobObserver already sends at the job level
 * (proof_of_delivery_submitted, delivery_confirmed) — needed because a
 * job with 2+ awards never itself transitions to 'delivered' (only a
 * single award does), so JobObserver::updated() would otherwise never
 * fire for a Tier 3 delivery at all.
 *
 * gps_signal_lost and job_completed_rate_prompt are deliberately NOT
 * mirrored here yet — see the Bulk Cargo Phase 2 plan's "Explicitly out of
 * scope" section; ratings aren't award-aware yet, and per-award GPS-lost
 * notification is a fast-follow once they are.
 */
class JobAwardObserver
{
    /**
     * Mirrors JobObserver::STATUS_MESSAGES — see that constant's own
     * docblock. One company's award reaching one of these checkpoints is
     * still real progress on the customer's shipment worth telling them
     * about, same as the Tier 1/2 case.
     *
     * @var array<string, string>
     */
    private const STATUS_MESSAGES = [
        'en_route_pickup' => 'The truck is on its way to pickup.',
        'picked_up' => 'Loading the cargo.',
        'in_transit' => 'Your cargo is in transit.',
    ];

    public function __construct(
        private readonly NotificationService $notifications,
    ) {}

    public function updated(JobAward $award): void
    {
        if (! $award->wasChanged('status')) {
            return;
        }

        $job = $award->job;

        if ($message = self::STATUS_MESSAGES[$award->status] ?? null) {
            $this->notifications->send($job->customer, 'job_status_changed', 'Shipment update', $message, $job);
        }

        if ($award->status === 'delivered') {
            $this->notifications->send($job->customer, 'proof_of_delivery_submitted', 'Delivery submitted', "Proof of delivery for one of Job #{$job->id}'s companies has been submitted. Review it and confirm receipt.", $job);
        }

        if ($award->status === 'completed' && $award->company?->owner !== null) {
            $this->notifications->send($award->company->owner, 'delivery_confirmed', 'Delivery confirmed', "The customer confirmed receipt for your part of Job #{$job->id}.", $job);
        }
    }
}
