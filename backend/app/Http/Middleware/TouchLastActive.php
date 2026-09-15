<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Backs the "haven't opened the app in a while" re-engagement nudge
 * (NudgeInactiveUsers) — last_active_at needs to reflect real usage, not
 * just login time, since a user can stay logged in (Sanctum tokens don't
 * expire) for weeks without ever opening the app again.
 *
 * Throttled to once per hour per user rather than every single request:
 * this runs on every authenticated call, and a plain `update()` on every
 * request would turn each API call into two writes for no real benefit —
 * the nudge command only cares about day-granularity staleness, so an
 * hour of slack is invisible to it.
 */
class TouchLastActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user !== null && (
            $user->last_active_at === null || $user->last_active_at->lt(now()->subHour())
        )) {
            $user->forceFill(['last_active_at' => now()])->saveQuietly();
        }

        return $next($request);
    }
}
