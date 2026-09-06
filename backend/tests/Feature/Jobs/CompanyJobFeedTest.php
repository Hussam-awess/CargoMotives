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
        Job::factory()->create(['status' => 'open']);
        Job::factory()->assigned()->create();

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
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
