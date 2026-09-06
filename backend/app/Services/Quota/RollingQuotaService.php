<?php

namespace App\Services\Quota;

use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Str;

/**
 * A true sliding-window rate limiter, backed by a Redis sorted set per key
 * (score = the action's timestamp). Deliberately not Laravel's simpler
 * `INCR` + `EXPIRE` pattern: that resets the whole quota at a fixed clock
 * boundary (a "fixed window"), so someone could use all 5 slots at 23:59
 * and all 5 again at 00:00 — 10 actions in two minutes. A sorted set lets
 * old entries age out continuously, matching the TRD's explicit "rolling-
 * window count" language for bid quotas (TRD §6) and the same shape for
 * customer job-post quotas (PRD §7.8).
 *
 * Shared by both quota types (App\Services\Bidding\BidQuotaService and the
 * customer post-quota check in JobController) rather than duplicated, since
 * the algorithm is identical — only the key, limit, and window differ.
 *
 * Failure points: if Redis is unreachable, this throws whatever the
 * underlying client throws (a connection exception) — callers should let
 * that surface as a 500 rather than silently allowing an unbounded number
 * of bids/posts through. Unlike OTP delivery or GPS, quota enforcement is
 * a trust/cost control, not a nice-to-have — "fail open" here isn't the
 * right kind of graceful degradation.
 */
class RollingQuotaService
{
    public function remaining(string $key, int $limit, int $windowSeconds): int
    {
        $this->pruneExpired($key, $windowSeconds);

        return max(0, $limit - Redis::zcard($key));
    }

    /**
     * @throws QuotaExceededException if the caller is already at the limit
     */
    public function consume(string $key, int $limit, int $windowSeconds): void
    {
        $this->pruneExpired($key, $windowSeconds);

        if (Redis::zcard($key) >= $limit) {
            throw new QuotaExceededException($this->secondsUntilSlotFrees($key, $windowSeconds));
        }

        $now = now()->timestamp;
        // A random member (not just the timestamp) so two actions in the
        // same second don't collide and silently overwrite one another in
        // the sorted set — ZADD requires unique members.
        Redis::zadd($key, $now, "{$now}:".Str::random(8));
        Redis::expire($key, $windowSeconds);
    }

    public function secondsUntilSlotFrees(string $key, int $windowSeconds): int
    {
        $this->pruneExpired($key, $windowSeconds);

        $oldest = Redis::zrange($key, 0, 0, ['withscores' => true]);
        if (empty($oldest)) {
            return 0;
        }

        $oldestTimestamp = (int) array_values($oldest)[0];

        return max(0, ($oldestTimestamp + $windowSeconds) - now()->timestamp);
    }

    private function pruneExpired(string $key, int $windowSeconds): void
    {
        Redis::zremrangebyscore($key, '-inf', now()->subSeconds($windowSeconds)->timestamp);
    }
}
