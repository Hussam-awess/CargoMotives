<?php

namespace Tests\Unit\Services\Jobs;

use App\Models\User;
use App\Services\Jobs\JobPostQuotaService;
use App\Services\Quota\QuotaExceededException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

/**
 * Safe to flushdb() — see phpunit.xml's REDIS_DB comment and
 * BidQuotaServiceTest's docblock.
 */
class JobPostQuotaServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Redis::flushdb();
        parent::tearDown();
    }

    public function test_a_standard_customer_gets_5_posts(): void
    {
        $customer = User::factory()->create();
        $service = app(JobPostQuotaService::class);

        $this->assertSame(5, $service->remaining($customer));
    }

    public function test_a_featured_customer_gets_10_posts(): void
    {
        $customer = User::factory()->create(['is_featured' => true]);
        $service = app(JobPostQuotaService::class);

        $this->assertSame(10, $service->remaining($customer));
    }

    public function test_throws_once_a_standard_customer_posts_5_jobs(): void
    {
        $customer = User::factory()->create();
        $service = app(JobPostQuotaService::class);

        for ($i = 0; $i < 5; $i++) {
            $service->consume($customer);
        }

        $this->expectException(QuotaExceededException::class);
        $service->consume($customer);
    }
}
