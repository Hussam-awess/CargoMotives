<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Redis;
use RuntimeException;
use Tests\TestCase;

/**
 * Covers HealthController's two failure-isolation guarantees: it reports
 * "ok" only when both dependencies are reachable, and a failure in one
 * check is reported specifically rather than masking the other (TRD's
 * general emphasis on clear, traceable failure — see the controller's own
 * docblock for the reasoning).
 *
 * The DB check runs against the real (sqlite, in-memory) test connection —
 * see phpunit.xml — so it's exercised for real rather than mocked. Redis is
 * mocked here since a live Redis server isn't a guaranteed part of the test
 * environment (e.g. CI, or local dev before `docker compose up`), and this
 * test should be deterministic either way.
 */
class HealthCheckTest extends TestCase
{
    public function test_health_check_reports_ok_when_dependencies_are_reachable(): void
    {
        Redis::shouldReceive('connection->ping')->once()->andReturn(true);

        $this->getJson('/api/health')
            ->assertOk()
            ->assertJson([
                'status' => 'ok',
                'checks' => [
                    'database' => ['ok' => true],
                    'redis' => ['ok' => true],
                ],
            ]);
    }

    public function test_health_check_reports_degraded_when_redis_is_unreachable(): void
    {
        Redis::shouldReceive('connection->ping')
            ->once()
            ->andThrow(new RuntimeException('Connection refused'));

        $response = $this->getJson('/api/health')
            ->assertStatus(503)
            ->assertJsonPath('status', 'degraded')
            ->assertJsonPath('checks.database.ok', true)
            ->assertJsonPath('checks.redis.ok', false);

        $this->assertSame('Connection refused', $response->json('checks.redis.error'));
    }
}
