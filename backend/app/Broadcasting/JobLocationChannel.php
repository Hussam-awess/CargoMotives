<?php

namespace App\Broadcasting;

use App\Models\Job;
use App\Models\User;

/**
 * Authorization for the job.{jobId}.location private channel (TRD §5.2) —
 * the second and last WebSocket use case in this app. Deliberately a
 * different channel from job.{jobId} (Phase 4's live bid updates, see
 * JobChannel): bids matter only to the customer, but a live position
 * matters to BOTH the customer and the assigned company watching the same
 * job, so this channel's join rule is broader than that one's.
 *
 * Class-based for the same reason as JobChannel: directly unit-testable
 * without a live Pusher-protocol broadcaster driver.
 */
class JobLocationChannel
{
    public function join(User $user, int $jobId): bool
    {
        $job = Job::find($jobId);
        if ($job === null) {
            return false;
        }

        if ((int) $job->customer_id === (int) $user->id) {
            return true;
        }

        return (int) $job->assignedCompany?->owner_user_id === (int) $user->id;
    }
}
