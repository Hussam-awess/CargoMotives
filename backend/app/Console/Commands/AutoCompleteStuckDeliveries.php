<?php

namespace App\Console\Commands;

use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Services\Jobs\ProofOfDeliveryService;
use App\Services\Notifications\NotificationService;
use Illuminate\Console\Command;

/**
 * The other half of the manual "End Job" escape hatch
 * (JobAssignmentController::submitProofOfDelivery()'s own docblock): if the
 * transporter never taps it either, a job would otherwise sit 'in_transit'
 * forever even once GPS has genuinely confirmed arrival and the drop-off
 * permit is attached. After a grace period, this sweep submits a photo-less,
 * explicitly-flagged system proof of delivery on the transporter's behalf —
 * never fabricating a driver_id (proof_of_deliveries.driver_id/driver_link_id
 * are NOT NULL), so a job with no driver link ever created is skipped, not
 * forced through.
 *
 * Mirrors CheckGpsSignalLoss's exact job+award dual-loop shape.
 */
class AutoCompleteStuckDeliveries extends Command
{
    protected $signature = 'jobs:auto-complete-stuck-deliveries';

    protected $description = 'Auto-complete a stuck in_transit job once GPS confirms arrival, the drop-off permit is attached, and the grace period has passed';

    private const AUTO_NOTE = 'Automatically completed — no action from the transporter within the grace period.';

    public function __construct(
        private readonly ProofOfDeliveryService $proofOfDelivery,
        private readonly NotificationService $notifications,
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $threshold = now()->subHours((int) config('gps.auto_complete_grace_period_hours', 3));
        $completed = 0;

        $jobs = Job::where('status', 'in_transit')
            ->whereNotNull('dropoff_permit_path')
            ->whereNotNull('dropoff_arrival_notified_at')
            ->where('dropoff_arrival_notified_at', '<=', $threshold)
            ->get();

        foreach ($jobs as $job) {
            $link = DriverLink::where('job_id', $job->id)->latest()->first();
            if ($link === null) {
                continue;
            }

            $this->proofOfDelivery->submit($job, null, $link, [], null, self::AUTO_NOTE, isSystemGenerated: true);
            $this->notify($job->fresh(), null);
            $completed++;
        }

        // Multi-Company Split Awards epic: an award has its own independent
        // status/GPS/permit-relevant timer (the permit itself stays
        // job-level — see the permit migrations' docblocks), so this scopes
        // separately from the job-level sweep above rather than assuming
        // trucks_needed <= 1.
        $awards = JobAward::where('status', 'in_transit')
            ->whereNotNull('dropoff_arrival_notified_at')
            ->where('dropoff_arrival_notified_at', '<=', $threshold)
            ->whereHas('job', fn ($q) => $q->whereNotNull('dropoff_permit_path'))
            ->get();

        foreach ($awards as $award) {
            $link = $award->leadTruckAssignment?->driverLink;
            if ($link === null) {
                continue;
            }

            $this->proofOfDelivery->submit($award->job, $award, $link, [], null, self::AUTO_NOTE, isSystemGenerated: true);
            $this->notify($award->job, $award->fresh());
            $completed++;
        }

        if ($completed > 0) {
            $this->info("Auto-completed {$completed} stuck delivery/deliveries.");
        }

        return self::SUCCESS;
    }

    private function notify(Job $job, ?JobAward $award): void
    {
        $body = "Job #{$job->id} was automatically marked delivered after reaching the drop-off point with all documents attached.";

        $this->notifications->send($job->customer, 'job_auto_completed', 'Delivery auto-completed', $body, $job);

        $owner = $award !== null ? $award->company?->owner : $job->assignedCompany?->owner;
        if ($owner !== null) {
            $this->notifications->send($owner, 'job_auto_completed', 'Delivery auto-completed', $body, $job);
        }
    }
}
