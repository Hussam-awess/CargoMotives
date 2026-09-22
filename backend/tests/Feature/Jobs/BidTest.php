<?php

namespace Tests\Feature\Jobs;

use App\Models\Bid;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use App\Services\Bidding\BidQuotaService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

/**
 * See BidQuotaServiceTest's docblock: safe to flushdb() because
 * phpunit.xml isolates tests onto their own Redis logical database.
 */
class BidTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Redis::flushdb();
        parent::tearDown();
    }

    private function approvedCompanyUser(array $companyAttributes = []): User
    {
        $user = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($user, 'owner')->create($companyAttributes);
        // Bulk Cargo epic: bidding now requires a verified fleet of at
        // least trucks_needed (1 for an ordinary job) — every real company
        // needs at least one approved truck to ever fulfill a job anyway.
        Truck::factory()->approved()->for($company, 'company')->create();

        return $user;
    }

    public function test_an_approved_company_can_place_a_bid_on_an_open_job(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['status' => 'open']);

        $response = $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/bids", [
            'price' => 500000,
            'note' => 'Can pick up today.',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.price', 500000)
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.company.verified', true);
    }

    /**
     * Bulk Cargo epic: the real, server-side gate — a company whose
     * verified fleet is smaller than trucks_needed cannot bid, even
     * hitting the API directly (not just a client that hides the form).
     */
    public function test_a_company_with_too_small_a_fleet_cannot_bid(): void
    {
        $companyUser = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($companyUser, 'owner')->create();
        // Deliberately no trucks at all — 0 verified trucks < the job's 5.
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 5]);

        $this->actingAs($companyUser)
            ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('company_id');

        $this->assertDatabaseMissing('bids', ['job_id' => $job->id]);
    }

    /**
     * Bidding Deadline epic: a second, independent gate from "is the job
     * still open" — a job can be status='open' with its deadline already
     * past (the customer just hasn't acted yet).
     */
    public function test_cannot_bid_once_the_jobs_bidding_deadline_has_passed(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['status' => 'open', 'bidding_expires_at' => now()->subHour()]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('bidding_expires_at');

        $this->assertDatabaseMissing('bids', ['job_id' => $job->id]);
    }

    public function test_can_still_bid_before_the_jobs_bidding_deadline(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['status' => 'open', 'bidding_expires_at' => now()->addDay()]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
            ->assertCreated();
    }

    public function test_cannot_bid_on_a_job_that_is_not_open(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->assigned()->create();

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
            ->assertUnprocessable();
    }

    public function test_cannot_place_a_second_pending_bid_on_the_same_job(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['status' => 'open']);
        Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $company->transporterCompany->id]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
            ->assertUnprocessable();
    }

    public function test_a_standard_company_is_limited_to_10_bids_per_rolling_window(): void
    {
        $company = $this->approvedCompanyUser();

        for ($i = 0; $i < 10; $i++) {
            $job = Job::factory()->create(['status' => 'open']);
            $this->actingAs($company)
                ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
                ->assertCreated();
        }

        $eleventhJob = Job::factory()->create(['status' => 'open']);
        $response = $this->actingAs($company)->postJson("/api/company/jobs/{$eleventhJob->id}/bids", ['price' => 500000]);
        $response->assertStatus(429)->assertJsonStructure(['seconds_until_slot_frees']);
    }

    /**
     * Cargo Motives Plus: no bid limit at all, not just a higher one.
     */
    public function test_a_featured_company_has_no_bid_limit(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => true]);

        for ($i = 0; $i < 25; $i++) {
            $job = Job::factory()->create(['status' => 'open']);
            $this->actingAs($company)
                ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
                ->assertCreated();
        }
    }

    public function test_a_featured_companys_bid_is_marked_priority(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => true]);
        $job = Job::factory()->create(['status' => 'open']);

        $response = $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000]);

        $response->assertCreated()->assertJsonPath('data.is_priority', true);
    }

    public function test_bid_quota_endpoint_reports_remaining(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['status' => 'open']);
        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000]);

        $this->actingAs($company)->getJson('/api/company/bid-quota')->assertOk()->assertJsonPath('remaining', 9);
    }

    public function test_bid_quota_endpoint_reports_unlimited_for_a_featured_company(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => true]);

        $this->actingAs($company)
            ->getJson('/api/company/bid-quota')
            ->assertOk()
            ->assertJsonPath('remaining', BidQuotaService::UNLIMITED);
    }

    public function test_a_company_can_withdraw_its_own_pending_bid(): void
    {
        $company = $this->approvedCompanyUser();
        $bid = Bid::factory()->create(['transporter_company_id' => $company->transporterCompany->id]);

        $response = $this->actingAs($company)->postJson("/api/company/bids/{$bid->id}/withdraw");

        $response->assertOk()->assertJsonPath('data.status', 'withdrawn');
    }

    public function test_a_company_cannot_withdraw_another_companys_bid(): void
    {
        $companyA = $this->approvedCompanyUser();
        $companyB = $this->approvedCompanyUser();
        $bid = Bid::factory()->create(['transporter_company_id' => $companyB->transporterCompany->id]);

        $this->actingAs($companyA)->postJson("/api/company/bids/{$bid->id}/withdraw")->assertNotFound();
    }

    public function test_customer_sees_all_bids_on_their_job_with_trust_profiles(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);
        Bid::factory()->create(['job_id' => $job->id]);
        Bid::factory()->create(['job_id' => $job->id, 'is_priority' => true]);

        $response = $this->actingAs($customer)->getJson("/api/jobs/{$job->id}/bids");

        $response->assertOk();
        $this->assertCount(2, $response->json('data'));
        // Featured/priority bid pinned first (PRD §7.4).
        $this->assertTrue($response->json('data.0.is_priority'));
    }

    public function test_customer_cannot_see_bids_on_another_customers_job(): void
    {
        $customerA = User::factory()->create();
        $customerB = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customerB->id]);

        $this->actingAs($customerA)->getJson("/api/jobs/{$job->id}/bids")->assertNotFound();
    }

    public function test_accepting_a_bid_assigns_the_job_and_rejects_other_bids(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);
        $winningBid = Bid::factory()->create(['job_id' => $job->id, 'price' => 750000]);
        $losingBid = Bid::factory()->create(['job_id' => $job->id, 'price' => 900000]);

        $response = $this->actingAs($customer)->postJson("/api/bids/{$winningBid->id}/accept");

        // A whole-number float round-trips through JSON without a decimal
        // point (json_encode(750000.0) is "750000"), which decodes back as
        // a PHP int — assertJsonPath's strict comparison needs 750000, not
        // 750000.0, to match what's actually in the response body.
        $response->assertOk()
            ->assertJsonPath('job.status', 'assigned')
            ->assertJsonPath('job.agreed_price', 750000)
            ->assertJsonPath('bid.status', 'accepted');

        $this->assertDatabaseHas('jobs', [
            'id' => $job->id,
            'status' => 'assigned',
            'assigned_company_id' => $winningBid->transporter_company_id,
            'assigned_bid_id' => $winningBid->id,
        ]);
        $this->assertDatabaseHas('bids', ['id' => $losingBid->id, 'status' => 'rejected']);
    }

    public function test_only_the_jobs_own_customer_can_accept_a_bid(): void
    {
        $customer = User::factory()->create();
        $otherCustomer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);
        $bid = Bid::factory()->create(['job_id' => $job->id]);

        $this->actingAs($otherCustomer)->postJson("/api/bids/{$bid->id}/accept")->assertNotFound();
    }

    public function test_cannot_accept_a_bid_on_a_job_that_is_no_longer_open(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->assigned()->create(['customer_id' => $customer->id]);
        $bid = Bid::factory()->create(['job_id' => $job->id]);

        $this->actingAs($customer)->postJson("/api/bids/{$bid->id}/accept")->assertUnprocessable();
    }

    public function test_cannot_accept_a_bid_that_is_no_longer_pending(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);
        $bid = Bid::factory()->withdrawn()->create(['job_id' => $job->id]);

        $this->actingAs($customer)->postJson("/api/bids/{$bid->id}/accept")->assertUnprocessable();
    }
}
