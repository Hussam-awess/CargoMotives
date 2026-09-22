<?php

namespace App\Observers;

use App\Models\CustomerFollow;
use App\Models\Job;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;
use App\Services\Notifications\NotificationService;

class JobObserver
{
    use ResolvesCurrentActor;

    /**
     * The customer-facing message for each status JobStatusAutoAdvancer (or
     * a driver's own manual tap on the Driver Link page — this fires either
     * way, see JobStatusAutoAdvancer's own docblock) can move a job into.
     * 'delivered'/'completed' keep their own dedicated blocks below (richer
     * wording, company-side notifications too) rather than folding into
     * this generic map.
     *
     * @var array<string, string>
     */
    private const STATUS_MESSAGES = [
        'en_route_pickup' => 'The truck is on its way to pickup.',
        'picked_up' => 'Loading the cargo.',
        'in_transit' => 'Your cargo is in transit.',
    ];

    public function __construct(
        private readonly ActivityLogger $activityLogger,
        private readonly NotificationService $notifications,
    ) {}

    /**
     * Not in AppFlow §6's own trigger map — every approved company can
     * already see every open job by browsing Jobs > Open (§2.4) — but
     * requested directly on top of it, as a proactive nudge. Originally
     * broadcast to *every* approved company (one row per recipient, same
     * as SupportMessage's Admin broadcast); that made this the single
     * noisiest notification in the app, since a company had no way to
     * narrow it down. Now scoped to only the companies following this
     * job's customer (the Follow system — see CustomerFollow/
     * FollowController) — a company that follows no one gets none of
     * these, by design. Still gated by the 'new_job_matches' preference on
     * top of that, so a company can mute it entirely even for customers it
     * follows.
     */
    public function created(Job $job): void
    {
        CustomerFollow::query()
            ->where('customer_id', $job->customer_id)
            ->with('transporterCompany.owner')
            ->chunk(100, function ($follows) use ($job) {
                foreach ($follows as $follow) {
                    $company = $follow->transporterCompany;

                    if ($company === null || $company->verification_status !== 'approved' || $company->owner === null) {
                        continue;
                    }

                    // Bulk Cargo epic, corrected by the Multi-Company
                    // Split Awards epic: a company with zero verified
                    // trucks structurally can never bid on anything and
                    // shouldn't be notified — but a small fleet CAN now
                    // legitimately bid on part of a big job, so it's no
                    // longer skipped just for being smaller than
                    // trucks_needed.
                    if ($company->verifiedTruckCount() === 0) {
                        continue;
                    }

                    $this->notifications->send(
                        $company->owner,
                        'new_job_posted',
                        'New shipment job',
                        "A new job just went up: {$job->pickup_address} \u{2192} {$job->dropoff_address}.",
                        $job,
                    );
                }
            });
    }

    public function updated(Job $job): void
    {
        if ($job->wasChanged('status')) {
            $this->activityLogger->record('job_status_changed', $job, $this->currentActorId(), [
                'from' => $job->getOriginal('status'),
                'to' => $job->status,
            ]);

            // Job status progress -> Customer, Push. Covers the three
            // checkpoints JobStatusAutoAdvancer drives off GPS position
            // (or a driver's own manual tap, which reaches the exact same
            // status column — this block doesn't know or care which).
            // 'delivered'/'completed' are their own richer blocks below.
            if ($message = self::STATUS_MESSAGES[$job->status] ?? null) {
                $this->notifications->send($job->customer, 'job_status_changed', 'Shipment update', $message, $job);
            }

            // AppFlow §6: "Proof of delivery submitted" -> Customer,
            // Company, Push. DriverLinkPageController::submitProofOfDelivery()
            // moves a job straight to 'delivered' in the same transaction
            // as creating the ProofOfDelivery row, so this status
            // transition IS that event — no separate ProofOfDelivery
            // observer needed.
            if ($job->status === 'delivered') {
                $this->notifications->send($job->customer, 'proof_of_delivery_submitted', 'Delivery submitted', "Proof of delivery for Job #{$job->id} has been submitted. Review it and confirm receipt.", $job);
                $this->notifyAssignedCompanyOwner($job, 'proof_of_delivery_submitted', 'Delivery submitted', "Proof of delivery for Job #{$job->id} has been submitted.");
            }

            // AppFlow §6: "Delivery confirmed" -> Company, Push.
            if ($job->status === 'completed') {
                $this->notifyAssignedCompanyOwner($job, 'delivery_confirmed', 'Delivery confirmed', "The customer confirmed receipt for Job #{$job->id}.");

                // Phase: ratings — a non-blocking nudge to both sides, not
                // in AppFlow §6's original trigger map. Whether either side
                // actually rates is entirely optional (JobResource.reviewable);
                // this is just the notification half of that prompt.
                $this->notifications->send($job->customer, 'job_completed_rate_prompt', 'Rate your experience', "Job #{$job->id} is complete. Let us know how it went.", $job);
                $this->notifyAssignedCompanyOwner($job, 'job_completed_rate_prompt', 'Rate your experience', "Job #{$job->id} is complete. Let us know how it went.");
            }
        }

        // AppFlow §6: "GPS signal lost mid-job" -> Customer + Company, Push
        // (in-app note, not urgent). Only the ok -> lost transition fires —
        // recovery back to 'ok' isn't in the trigger map.
        if ($job->wasChanged('gps_signal_status') && $job->gps_signal_status === 'lost') {
            $this->notifications->send($job->customer, 'gps_signal_lost', 'GPS signal unavailable', "GPS tracking for Job #{$job->id} has gone quiet. The job itself is unaffected.", $job);
            $this->notifyAssignedCompanyOwner($job, 'gps_signal_lost', 'GPS signal unavailable', "GPS tracking for Job #{$job->id} has gone quiet.");
        }
    }

    /**
     * assigned_company_id is nullable on the model (Backend Schema §2.7)
     * and JobAssignmentService is the only real-world path that sets it
     * alongside a truck — a handful of test fixtures build a job with
     * gps_tracking_active/an assigned truck but no assigned company, which
     * would otherwise crash this observer on ->owner of null.
     */
    private function notifyAssignedCompanyOwner(Job $job, string $type, string $title, string $body): void
    {
        if ($job->assignedCompany?->owner === null) {
            return;
        }

        $this->notifications->send($job->assignedCompany->owner, $type, $title, $body, $job);
    }
}
