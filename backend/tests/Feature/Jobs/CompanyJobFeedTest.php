<?php

namespace Tests\Feature\Jobs;

use App\Models\Bid;
use App\Models\CustomerFollow;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CompanyJobFeedTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    public function test_open_feed_shows_only_open_jobs(): void
    {
        $company = $this->approvedCompanyUser();
        // Backdated past the "early visibility" window (Phase 10.19) —
        // this test is about status filtering, not the Plus-benefit
        // timing gate, which has its own dedicated tests below.
        Job::factory()->create(['status' => 'open', 'created_at' => now()->subMinutes(5)]);
        Job::factory()->assigned()->create();

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    /**
     * Bidding Deadline epic: "no longer visible as an available bidding
     * opportunity" once its deadline passes — status alone (still 'open')
     * isn't enough to keep it in this feed.
     */
    public function test_open_feed_excludes_a_job_whose_bidding_deadline_has_passed(): void
    {
        $company = $this->approvedCompanyUser();
        Job::factory()->create(['status' => 'open', 'created_at' => now()->subMinutes(5), 'bidding_expires_at' => now()->subHour()]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk();
        $this->assertCount(0, $response->json('data'));
    }

    public function test_open_feed_includes_a_job_whose_bidding_deadline_has_not_passed_yet(): void
    {
        $company = $this->approvedCompanyUser();
        Job::factory()->create(['status' => 'open', 'created_at' => now()->subMinutes(5), 'bidding_expires_at' => now()->addDay()]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    public function test_open_feed_shows_the_posting_customers_business_identity(): void
    {
        // Phase 11 product decision: a Customer's optional company_name
        // is shown to companies bidding on their jobs, not just the
        // customer themselves — see JobResource/users.company_name.
        $company = $this->approvedCompanyUser();
        $customer = User::factory()->create(['full_name' => 'Amina Hassan', 'company_name' => 'Amina Textiles Ltd']);
        Job::factory()->create(['status' => 'open', 'customer_id' => $customer->id, 'created_at' => now()->subMinutes(5)]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk()
            ->assertJsonPath('data.0.customer_name', 'Amina Hassan')
            ->assertJsonPath('data.0.customer_company_name', 'Amina Textiles Ltd');
    }

    public function test_open_feed_shows_whether_the_viewing_company_already_follows_the_customer(): void
    {
        $company = $this->approvedCompanyUser();
        $followed = User::factory()->create();
        $notFollowed = User::factory()->create();
        CustomerFollow::create([
            'transporter_company_id' => $company->transporterCompany->id,
            'customer_id' => $followed->id,
        ]);
        Job::factory()->create(['status' => 'open', 'customer_id' => $followed->id, 'created_at' => now()->subMinutes(5)]);
        Job::factory()->create(['status' => 'open', 'customer_id' => $notFollowed->id, 'created_at' => now()->subMinutes(5)]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk();
        $byCustomer = collect($response->json('data'))->keyBy('customer_name');
        $this->assertTrue($byCustomer[$followed->full_name]['is_following_customer']);
        $this->assertFalse($byCustomer[$notFollowed->full_name]['is_following_customer']);
    }

    public function test_open_feed_shows_the_customers_budget_price_so_a_company_can_bid_informed(): void
    {
        $company = $this->approvedCompanyUser();
        Job::factory()->create(['status' => 'open', 'budget_price' => 850000, 'created_at' => now()->subMinutes(5)]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk()->assertJsonPath('data.0.budget_price', 850000);
    }

    public function test_a_non_featured_company_does_not_see_a_job_posted_less_than_2_minutes_ago(): void
    {
        $company = $this->approvedCompanyUser();
        Job::factory()->create(['status' => 'open', 'created_at' => now()]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk();
        $this->assertCount(0, $response->json('data'));
    }

    public function test_a_featured_company_sees_a_job_posted_seconds_ago(): void
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create(['is_featured' => true]);
        Job::factory()->create(['status' => 'open', 'created_at' => now()]);

        $response = $this->actingAs($user)->getJson('/api/company/jobs/open');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    public function test_a_featured_customers_job_sorts_above_a_standard_customers_job(): void
    {
        $company = $this->approvedCompanyUser();
        $standardCustomer = User::factory()->create(['is_featured' => false]);
        $featuredCustomer = User::factory()->create(['is_featured' => true]);
        $olderFromFeatured = Job::factory()->create([
            'status' => 'open',
            'customer_id' => $featuredCustomer->id,
            'created_at' => now()->subMinutes(10),
        ]);
        $newerFromStandard = Job::factory()->create([
            'status' => 'open',
            'customer_id' => $standardCustomer->id,
            'created_at' => now()->subMinutes(5),
        ]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertSame([$olderFromFeatured->id, $newerFromStandard->id], $ids);
    }

    public function test_open_feed_includes_the_posting_customers_real_completed_shipment_count(): void
    {
        $company = $this->approvedCompanyUser();
        $customer = User::factory()->create();
        Job::factory()->count(2)->create(['customer_id' => $customer->id, 'status' => 'completed']);
        Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open', 'created_at' => now()->subMinutes(5)]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk()->assertJsonPath('data.0.customer_completed_jobs_count', 2);
    }

    public function test_my_bids_shows_only_jobs_this_company_bid_on(): void
    {
        $company = $this->approvedCompanyUser();
        $ourBid = Bid::factory()->create(['transporter_company_id' => $company->transporterCompany->id]);
        Bid::factory()->create(); // some other company's bid on a different job

        $response = $this->actingAs($company)->getJson('/api/company/jobs/my-bids');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
        $this->assertSame($ourBid->job_id, $response->json('data.0.id'));
    }

    public function test_active_shows_only_jobs_assigned_to_this_company(): void
    {
        $company = $this->approvedCompanyUser();
        Job::factory()->assigned()->create(['assigned_company_id' => $company->transporterCompany->id]);
        Job::factory()->assigned()->create(); // assigned to a different company

        $response = $this->actingAs($company)->getJson('/api/company/jobs/active');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    public function test_a_company_can_view_an_open_jobs_detail(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['status' => 'open']);

        $this->actingAs($company)->getJson("/api/company/jobs/{$job->id}")->assertOk();
    }

    public function test_a_company_cannot_view_an_unrelated_non_open_job(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->assigned()->create(); // assigned to someone else, not open

        $this->actingAs($company)->getJson("/api/company/jobs/{$job->id}")->assertNotFound();
    }

    public function test_an_unapproved_company_cannot_access_the_open_feed(): void
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->for($user, 'owner')->create(); // still pending

        $this->actingAs($user)->getJson('/api/company/jobs/open')->assertForbidden();
    }

    /**
     * Multi-Company Split Awards epic: a company with zero verified trucks
     * structurally can never bid on anything, regardless of the job's
     * trucks_needed or remaining capacity.
     */
    public function test_open_feed_marks_a_job_ineligible_when_the_company_has_no_verified_trucks(): void
    {
        $company = $this->approvedCompanyUser();
        Job::factory()->create(['status' => 'open', 'trucks_needed' => 5, 'created_at' => now()->subMinutes(5)]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk()->assertJsonPath('data.0.is_eligible', false);
    }

    /**
     * Multi-Company Split Awards epic: is_eligible no longer requires a
     * company's fleet to single-handedly cover the whole job — one
     * verified truck is enough to be eligible for a slice of a much
     * bigger job. The all-or-nothing gate this replaced now only lives in
     * BidController::store()'s per-bid trucks_offered check.
     */
    public function test_open_feed_marks_a_job_eligible_when_the_company_has_a_small_fleet_but_capacity_remains(): void
    {
        $company = $this->approvedCompanyUser();
        Truck::factory()->approved()->for($company->transporterCompany, 'company')->create();
        Job::factory()->create(['status' => 'open', 'trucks_needed' => 5, 'created_at' => now()->subMinutes(5)]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk()
            ->assertJsonPath('data.0.is_eligible', true)
            ->assertJsonPath('data.0.remaining_trucks_needed', 5);
    }

    public function test_open_feed_marks_a_job_eligible_when_the_companys_fleet_is_large_enough(): void
    {
        $company = $this->approvedCompanyUser();
        Truck::factory()->approved()->count(5)->for($company->transporterCompany, 'company')->create();
        Job::factory()->create(['status' => 'open', 'trucks_needed' => 5, 'created_at' => now()->subMinutes(5)]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk()->assertJsonPath('data.0.is_eligible', true);
    }

    /**
     * Multi-Company Split Awards epic: once every truck on a job has
     * already been awarded to other companies, remaining capacity is 0 —
     * a company with plenty of its own trucks is still ineligible, since
     * there's nothing left to bid for.
     */
    public function test_open_feed_marks_a_job_ineligible_once_its_remaining_capacity_is_fully_awarded(): void
    {
        $company = $this->approvedCompanyUser();
        Truck::factory()->approved()->count(5)->for($company->transporterCompany, 'company')->create();
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 5, 'created_at' => now()->subMinutes(5)]);

        $otherCompany = $this->approvedCompanyUser()->transporterCompany;
        $bid = Bid::factory()->for($job)->for($otherCompany, 'company')->create(['trucks_offered' => 5]);
        JobAward::create([
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $otherCompany->id,
            'trucks_offered' => 5,
            'agreed_price' => $bid->price,
        ]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk()
            ->assertJsonPath('data.0.is_eligible', false)
            ->assertJsonPath('data.0.remaining_trucks_needed', 0);
    }

    public function test_job_detail_reflects_the_viewing_companys_eligibility(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 3]);

        $this->actingAs($company)
            ->getJson("/api/company/jobs/{$job->id}")
            ->assertOk()
            ->assertJsonPath('data.is_eligible', false);
    }
}
