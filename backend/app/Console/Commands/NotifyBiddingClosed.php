<?php

namespace App\Console\Commands;

use App\Models\Job;
use App\Services\Notifications\NotificationService;
use Illuminate\Console\Command;

/**
 * Bidding Deadline epic: the one-time notification when a job's bidding
 * window closes on its own (never on acceptance/cancellation — those have
 * their own notifications already). Deliberately never auto-assigns
 * anyone, per the product decision behind this whole epic — the customer
 * always makes the final call, this command only tells them the window has
 * closed and what their options are.
 *
 * bidding_expiry_notified_at is the guard: stamped the instant a job is
 * processed here, so a job scanned again on the next run (still 'open',
 * deadline still in the past, because the customer hasn't acted) is never
 * double-notified.
 */
class NotifyBiddingClosed extends Command
{
    protected $signature = 'jobs:notify-bidding-closed';

    protected $description = "Notify a job's customer once its bidding deadline passes, exactly once";

    public function handle(NotificationService $notifications): int
    {
        Job::query()
            ->where('status', 'open')
            ->whereNotNull('bidding_expires_at')
            ->where('bidding_expires_at', '<=', now())
            ->whereNull('bidding_expiry_notified_at')
            ->with('customer')
            ->chunkById(200, function ($jobs) use ($notifications) {
                foreach ($jobs as $job) {
                    $hasPendingBids = $job->bids()->where('status', 'pending')->exists();

                    if ($hasPendingBids) {
                        $notifications->send(
                            $job->customer,
                            'bidding_closed_has_bids',
                            'Bidding closed — pick a transporter',
                            "Bidding for Job #{$job->id} has closed. Review the bids and choose who you'd like to work with.",
                            $job,
                        );
                    } else {
                        $notifications->send(
                            $job->customer,
                            'bidding_closed_no_bids',
                            'Bidding closed — no bids',
                            "Nobody bid on Job #{$job->id} before the deadline. Repost it whenever you're ready.",
                            $job,
                        );
                    }

                    $job->forceFill(['bidding_expiry_notified_at' => now()])->saveQuietly();
                }
            });

        return self::SUCCESS;
    }
}
