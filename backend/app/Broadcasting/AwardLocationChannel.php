<?php

namespace App\Broadcasting;

use App\Models\JobAward;
use App\Models\User;

/**
 * Authorization for the award.{awardId}.location private channel (Multi-
 * Company Split Awards epic) — the per-company equivalent of
 * JobLocationChannel. Joinable by the job's customer (who cares about
 * every award on their job) or that ONE award's own company owner —
 * never any other awarded company on the same job.
 */
class AwardLocationChannel
{
    public function join(User $user, int $awardId): bool
    {
        $award = JobAward::with('job')->find($awardId);
        if ($award === null) {
            return false;
        }

        if ((int) $award->job->customer_id === (int) $user->id) {
            return true;
        }

        return (int) $award->company?->owner_user_id === (int) $user->id;
    }
}
