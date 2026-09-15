<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Notifications\NotificationService;
use Illuminate\Console\Command;

/**
 * Not part of AppFlow §6's own trigger map — a proactive re-engagement
 * nudge added on top of it, for a Customer or Company that's gone quiet.
 *
 * Two timestamps, not one, keep this from re-notifying someone every
 * single day they stay away: last_active_at (touched by TouchLastActive
 * on real usage) says WHETHER they're inactive; last_inactivity_nudge_at
 * says whether they've already been told, so a user who ignores the nudge
 * gets it again after another full INACTIVITY_DAYS window, not daily.
 * Admin accounts are excluded — they're operators, not the audience for a
 * "come back and post a job" style message.
 */
class NudgeInactiveUsers extends Command
{
    protected $signature = 'notifications:nudge-inactive-users';

    protected $description = 'Send a re-engagement push to users who have not opened the app in a while';

    private const INACTIVITY_DAYS = 7;

    public function handle(NotificationService $notifications): int
    {
        $cutoff = now()->subDays(self::INACTIVITY_DAYS);

        User::query()
            ->where('account_type', '!=', 'admin')
            ->where('last_active_at', '<', $cutoff)
            ->where(function ($query) use ($cutoff) {
                $query->whereNull('last_inactivity_nudge_at')
                    ->orWhere('last_inactivity_nudge_at', '<', $cutoff);
            })
            ->chunkById(200, function ($users) use ($notifications) {
                foreach ($users as $user) {
                    $body = $user->account_type === 'customer'
                        ? "It's been a while — post a shipment and get bids from verified transporters."
                        : "It's been a while — check the Open jobs feed for loads you can bid on.";

                    $notifications->send($user, 're_engagement', 'We miss you at Cargo Motives', $body);

                    $user->forceFill(['last_inactivity_nudge_at' => now()])->saveQuietly();
                }
            });

        return self::SUCCESS;
    }
}
