<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Sanctum tokens here have no absolute expiry (a daily-use app shouldn't
 * log people out on a timer), so without this a token on a lost or
 * replaced phone would stay valid forever. Revokes any session idle for
 * config('security.session_idle_days') — measured from last use, or from
 * creation for a token that was never used at all.
 */
class PruneStaleSessions extends Command
{
    protected $signature = 'auth:prune-stale-sessions';

    protected $description = 'Revoke sign-in sessions that have not been used in a long time';

    public function handle(): int
    {
        $cutoff = now()->subDays((int) config('security.session_idle_days'));

        $deleted = PersonalAccessToken::query()
            ->where(function ($query) use ($cutoff) {
                $query->where('last_used_at', '<', $cutoff)
                    ->orWhere(fn ($q) => $q->whereNull('last_used_at')->where('created_at', '<', $cutoff));
            })
            ->delete();

        $this->info("Revoked {$deleted} stale session(s).");

        return self::SUCCESS;
    }
}
