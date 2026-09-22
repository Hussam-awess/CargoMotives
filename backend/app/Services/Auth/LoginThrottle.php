<?php

namespace App\Services\Auth;

use Illuminate\Support\Facades\Cache;

/**
 * Account-level login lockout, independent of IP — keyed only on the
 * identifier being logged into (phone/email, namespaced per role by the
 * caller so a Customer and Transporter Company never share a bucket).
 *
 * Complements, rather than replaces, the per-route `throttle:*` rate
 * limiters in AppServiceProvider: those key on identifier+IP together, so
 * an attacker who simply rotates IPs sails past them untouched. This still
 * catches that, since it never looks at the request's IP at all.
 */
class LoginThrottle
{
    public function locked(string $key): bool
    {
        return Cache::has($this->lockKey($key));
    }

    public function secondsRemaining(string $key): int
    {
        $unlocksAtTimestamp = Cache::get($this->lockKey($key));

        return is_int($unlocksAtTimestamp) ? max(0, $unlocksAtTimestamp - now()->timestamp) : 0;
    }

    /**
     * Locks the identifier once config('security.login_max_attempts') is
     * reached within the lockout window.
     */
    public function recordFailure(string $key): void
    {
        $attemptsKey = $this->attemptsKey($key);
        $decayAt = now()->addMinutes(config('security.login_lockout_minutes'));

        $attempts = (int) Cache::get($attemptsKey, 0) + 1;
        Cache::put($attemptsKey, $attempts, $decayAt);

        if ($attempts >= config('security.login_max_attempts')) {
            Cache::put($this->lockKey($key), $decayAt->timestamp, $decayAt);
        }
    }

    public function clear(string $key): void
    {
        Cache::forget($this->attemptsKey($key));
        Cache::forget($this->lockKey($key));
    }

    private function attemptsKey(string $key): string
    {
        return "login_throttle:{$key}:attempts";
    }

    private function lockKey(string $key): string
    {
        return "login_throttle:{$key}:locked";
    }
}
