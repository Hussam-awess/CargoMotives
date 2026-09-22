<?php

namespace App\Http\Controllers\Concerns;

use Illuminate\Http\JsonResponse;

/**
 * Shared 429 response shape for a LoginThrottle lockout — same
 * cooldown-response pattern as OtpCooldownException's callers (a generic
 * message plus seconds_remaining, never which field/account triggered it).
 */
trait HandlesLoginLockout
{
    protected function lockoutResponse(string $key): JsonResponse
    {
        return response()->json([
            'message' => 'Too many failed attempts. Please try again later.',
            'seconds_remaining' => $this->loginThrottle->secondsRemaining($key),
        ], 429);
    }
}
