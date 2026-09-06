<?php

namespace App\Broadcasting;

use App\Models\Job;
use App\Models\User;

/**
 * Authorization for the job.{jobId} private channel (TRD §4's live bid
 * updates). A class, not an inline closure in routes/channels.php,
 * specifically so this rule is unit-testable directly — exercising it
 * through the actual /broadcasting/auth HTTP endpoint requires a real
 * Pusher-protocol broadcaster driver wired up with valid signing
 * credentials (NullBroadcaster, used everywhere else in tests, is a bare
 * no-op that never calls this at all), which tests Laravel's broadcaster
 * internals more than it tests this rule.
 */
class JobChannel
{
    public function join(User $user, int $jobId): bool
    {
        // Explicit casts: customer_id isn't declared with an int cast on
        // the Job model (it's a plain FK column), so a strict === against
        // $user->id (which Eloquent does cast to int, as the primary key)
        // could mismatch string vs int depending on the DB driver's
        // fetch mode.
        return (int) Job::find($jobId)?->customer_id === (int) $user->id;
    }
}
