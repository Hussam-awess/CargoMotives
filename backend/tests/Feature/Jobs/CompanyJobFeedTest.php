<?php

namespace Tests\Feature\Jobs;

use App\Models\Bid;
use App\Models\Job;
use App\Models\TransporterCompany;
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
}
