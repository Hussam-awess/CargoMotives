<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Throwable;

/**
 * Unauthenticated liveness/readiness check for the API.
 *
 * Purpose: let local dev (and later, a deploy pipeline / uptime monitor)
 * confirm the app can actually reach its two hard dependencies — Postgres
 * and Redis — rather than just confirming PHP itself is running. This is
 * intentionally the first thing built (Phase 0): every later phase assumes
 * both are reachable, so a fast, clear failure here saves time debugging
 * something that looks like an app bug but is actually "Postgres isn't up."
 *
 * Failure points this guards against, and how to trace them:
 *  - DB unreachable: wrong DB_* env vars, Postgres container not started/healthy,
 *    or the `cargo_motives` database/role not created yet.
 *  - Redis unreachable: wrong REDIS_* env vars, Redis container not started,
 *    or (locally, outside Docker) no Redis process running on 127.0.0.1:6379.
 * Each check is isolated so one failing dependency doesn't mask the other.
 */
class HealthController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $checks = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
        ];

        $healthy = collect($checks)->every(fn (array $check) => $check['ok']);

        return response()->json([
            'status' => $healthy ? 'ok' : 'degraded',
            'checks' => $checks,
        ], $healthy ? 200 : 503);
    }

    /**
     * @return array{ok: bool, error?: string}
     */
    private function checkDatabase(): array
    {
        try {
            DB::connection()->getPdo();

            return ['ok' => true];
        } catch (Throwable $e) {
            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * @return array{ok: bool, error?: string}
     */
    private function checkRedis(): array
    {
        try {
            Redis::connection()->ping();

            return ['ok' => true];
        } catch (Throwable $e) {
            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }
}
