<?php

namespace App\Observers;

use App\Models\Job;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;
use App\Services\Notifications\NotificationService;

class JobObserver
{
    use ResolvesCurrentActor;

    public function __construct(
        private readonly ActivityLogger $activityLogger,
        private readonly NotificationService $notifications,
    ) {}

    public function updated(Job $job): void
    {
        if ($job->wasChanged('status')) {
            $this->activityLogger->record('job_status_changed', $job, $this->currentActorId(), [
                'from' => $job->getOriginal('status'),
                'to' => $job->status,
            ]);

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
                $this->notifyAssignedCompanyOwner($job, 'delivery_confirmed', 'Delivery confirmed', "The customer confirmed receipt for Job #{$job->id}. Commission has been added to your balance.");
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
