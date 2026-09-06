<?php

namespace Tests\Unit\Services\Quota;

use App\Services\Quota\QuotaExceededException;
use App\Services\Quota\RollingQuotaService;
use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

/**
 * Exercises the sorted-set rolling window directly against a real Redis
 * connection (not mocked) — the whole point of this service is precise
 * time-based behavior that a mock would just assert away. Safe to
 * flushdb() in tearDown: phpunit.xml points REDIS_DB at a logical database
 * dedicated to tests, isolated from both dev usage (DB 0) and the cache
 * connection (DB 1) — see phpunit.xml's comment for why that isolation
 * matters here specifically.
 */
class RollingQuotaServiceTest extends TestCase
{
    private RollingQuotaService $service;

    private string $key;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new RollingQuotaService;
        $this->key = 'test:quota:key';
    }

    protected function tearDown(): void
    {
        Redis::flushdb();
        parent::tearDown();
    }

    public function test_remaining_starts_at_the_full_limit(): void
    {
        $this->assertSame(5, $this->service->remaining($this->key, 5, 3600));
    }

    public function test_consume_decrements_remaining(): void
    {
        $this->service->consume($this->key, 5, 3600);
        $this->service->consume($this->key, 5, 3600);

        $this->assertSame(3, $this->service->remaining($this->key, 5, 3600));
    }

    public function test_consume_throws_once_the_limit_is_reached(): void
    {
        for ($i = 0; $i < 3; $i++) {
            $this->service->consume($this->key, 3, 3600);
        }

        $this->expectException(QuotaExceededException::class);
        $this->service->consume($this->key, 3, 3600);
    }

    public function test_entries_older_than_the_window_are_pruned(): void
    {
        // Simulate an action from 2 hours ago directly, bypassing consume()
        // (which always timestamps "now") — a 1-hour window should treat
        // it as expired.
        Redis::zadd($this->key, now()->subHours(2)->timestamp, 'old-entry');

        $this->assertSame(5, $this->service->remaining($this->key, 5, 3600));
    }

    public function test_seconds_until_slot_frees_reflects_the_oldest_entry(): void
    {
        Redis::zadd($this->key, now()->subMinutes(50)->timestamp, 'entry-1');

        // 1-hour window; oldest entry is 50 minutes old -> ~10 minutes (600s) left.
        $seconds = $this->service->secondsUntilSlotFrees($this->key, 3600);

        $this->assertGreaterThan(0, $seconds);
        $this->assertLessThanOrEqual(600, $seconds);
    }

    public function test_seconds_until_slot_frees_is_zero_when_nothing_is_recorded(): void
    {
        $this->assertSame(0, $this->service->secondsUntilSlotFrees($this->key, 3600));
    }
}
