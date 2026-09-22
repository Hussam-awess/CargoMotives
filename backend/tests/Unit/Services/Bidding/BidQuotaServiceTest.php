<?php

namespace Tests\Unit\Services\Bidding;

use App\Models\TransporterCompany;
use App\Services\Bidding\BidQuotaService;
use App\Services\Quota\QuotaExceededException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

/**
 * Safe to flushdb() in tearDown — see phpunit.xml's REDIS_DB comment and
 * RollingQuotaServiceTest's docblock: tests run against an isolated Redis
 * logical database, dedicated to this purpose specifically because an
 * earlier version of this cleanup (scanning Redis::keys() then handing
 * the results to Redis::del()) silently deleted nothing — Laravel's
 * configured key prefix gets applied a second time on the round trip —
 * and leaked real quota state into this machine's shared dev Redis.
 */
class BidQuotaServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Redis::flushdb();
        parent::tearDown();
    }

    public function test_a_standard_company_gets_10_bids(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $service = app(BidQuotaService::class);

        $this->assertSame(10, $service->remaining($company));
    }

    public function test_a_featured_company_has_no_limit(): void
    {
        $company = TransporterCompany::factory()->approved()->create(['is_featured' => true]);
        $service = app(BidQuotaService::class);

        $this->assertSame(BidQuotaService::UNLIMITED, $service->remaining($company));
    }

    public function test_consuming_reduces_that_specific_companys_quota_only(): void
    {
        $companyA = TransporterCompany::factory()->approved()->create();
        $companyB = TransporterCompany::factory()->approved()->create();
        $service = app(BidQuotaService::class);

        $service->consume($companyA);

        $this->assertSame(9, $service->remaining($companyA));
        $this->assertSame(10, $service->remaining($companyB));
    }

    public function test_throws_once_a_standard_company_places_10_bids(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $service = app(BidQuotaService::class);

        for ($i = 0; $i < 10; $i++) {
            $service->consume($company);
        }

        $this->expectException(QuotaExceededException::class);
        $service->consume($company);
    }

    /**
     * A Featured company never touches the rolling-quota counter at all —
     * placing far more bids than the standard limit never throws.
     */
    public function test_a_featured_company_never_hits_a_limit(): void
    {
        $company = TransporterCompany::factory()->approved()->create(['is_featured' => true]);
        $service = app(BidQuotaService::class);

        for ($i = 0; $i < 25; $i++) {
            $service->consume($company);
        }

        $this->assertSame(BidQuotaService::UNLIMITED, $service->remaining($company));
    }
}
