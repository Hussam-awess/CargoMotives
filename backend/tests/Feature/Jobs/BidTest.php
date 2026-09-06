<?php

namespace Tests\Feature\Jobs;

use App\Models\Bid;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
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
        TransporterCompany::factory()->approved()->for($user, 'owner')->create($companyAttributes);

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

    public function test_a_company_on_hold_cannot_bid(): void
    {
        $company = $this->approvedCompanyUser(['commission_standing' => 'on_hold']);
        $job = Job::factory()->create(['status' => 'open']);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
            ->assertUnprocessable();
    }

    public function test_a_standard_company_is_limited_to_5_bids_per_rolling_window(): void
    {
        $company = $this->approvedCompanyUser();

        for ($i = 0; $i < 5; $i++) {
            $job = Job::factory()->create(['status' => 'open']);
            $this->actingAs($company)
                ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
                ->assertCreated();
        }

        $sixthJob = Job::factory()->create(['status' => 'open']);
        $response = $this->actingAs($company)->postJson("/api/company/jobs/{$sixthJob->id}/bids", ['price' => 500000]);
        $response->assertStatus(429)->assertJsonStructure(['seconds_until_slot_frees']);
    }

    public function test_a_featured_company_is_limited_to_10_bids(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => true]);

        for ($i = 0; $i < 10; $i++) {
            $job = Job::factory()->create(['status' => 'open']);
            $this->actingAs($company)
                ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
                ->assertCreated();
        }

        $eleventhJob = Job::factory()->create(['status' => 'open']);
        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$eleventhJob->id}/bids", ['price' => 500000])
            ->assertStatus(429);
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

        $this->actingAs($company)->getJson('/api/company/bid-quota')->assertOk()->assertJsonPath('remaining', 4);
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
