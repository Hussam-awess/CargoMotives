<?php

namespace Tests\Feature\Jobs;

use App\Models\Bid;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\TransporterCompany;
use App\Models\User;
use App\Services\Geo\GeoPoint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The "Return Loads" tab (CompanyJobController::returnLoads()) — a
 * persistent, browsable version of returnLoadSuggestions() anchored on
 * every one of this company's own relevant jobs at once, rather than one
 * specific just-delivered job.
 */
class ReturnLoadsListTest extends TestCase
{
    use RefreshDatabase;

    private function featuredCompanyUser(array $companyAttributes = []): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create([
            'is_featured' => true,
            'featured_until' => now()->addMonth(),
            ...$companyAttributes,
        ]);

        return $user;
    }

    public function test_a_non_featured_company_is_forbidden(): void
    {
        $companyUser = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($companyUser, 'owner')->create(['is_featured' => false]);

        $this->actingAs($companyUser)->getJson('/api/company/jobs/return-loads')->assertForbidden();
    }

    public function test_matches_open_jobs_near_a_currently_assigned_jobs_dropoff(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $companyId = $companyUser->transporterCompany->id;

        // Still in progress — not delivered/completed yet, but its dropoff
        // point is a legitimate anchor: a return load matters just as much
        // while a company is still en route as right after it delivers.
        Job::factory()->create(['assigned_company_id' => $companyId, 'status' => 'in_transit']);

        $nearby = Job::factory()->create(['status' => 'open', 'budget_price' => 400000]);

        $response = $this->actingAs($companyUser)->getJson('/api/company/jobs/return-loads');

        $response->assertOk();
        $this->assertTrue(collect($response->json('data'))->pluck('id')->contains($nearby->id));
    }

    public function test_matches_against_a_recently_completed_jobs_dropoff(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $companyId = $companyUser->transporterCompany->id;

        Job::factory()->create([
            'assigned_company_id' => $companyId,
            'status' => 'completed',
            'completed_at' => now()->subDays(5),
        ]);
        $nearby = Job::factory()->create(['status' => 'open', 'budget_price' => 400000]);

        $response = $this->actingAs($companyUser)->getJson('/api/company/jobs/return-loads');

        $response->assertOk();
        $this->assertTrue(collect($response->json('data'))->pluck('id')->contains($nearby->id));
    }

    public function test_ignores_a_completion_from_too_long_ago(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $companyId = $companyUser->transporterCompany->id;

        Job::factory()->create([
            'assigned_company_id' => $companyId,
            'status' => 'completed',
            'completed_at' => now()->subDays(90),
        ]);
        $nearby = Job::factory()->create(['status' => 'open', 'budget_price' => 400000]);

        $response = $this->actingAs($companyUser)->getJson('/api/company/jobs/return-loads');

        $response->assertOk();
        $this->assertFalse(collect($response->json('data'))->pluck('id')->contains($nearby->id));
    }

    public function test_a_job_far_from_every_anchor_is_not_matched(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $companyId = $companyUser->transporterCompany->id;

        Job::factory()->create(['assigned_company_id' => $companyId, 'status' => 'in_transit']);

        // Mwanza, ~1000km from the factory's Dar es Salaam jobs — well
        // outside the 50km return-load radius.
        $farAway = Job::factory()->create([
            'status' => 'open',
            'budget_price' => 400000,
            'pickup_location' => (new GeoPoint(-2.516, 32.900))->toInsertExpression(),
        ]);

        $response = $this->actingAs($companyUser)->getJson('/api/company/jobs/return-loads');

        $response->assertOk();
        $this->assertFalse(collect($response->json('data'))->pluck('id')->contains($farAway->id));
    }

    public function test_returns_empty_when_the_company_has_no_relevant_jobs_at_all(): void
    {
        $companyUser = $this->featuredCompanyUser();
        Job::factory()->create(['status' => 'open', 'budget_price' => 400000]);

        $response = $this->actingAs($companyUser)->getJson('/api/company/jobs/return-loads');

        $response->assertOk();
        $this->assertEmpty($response->json('data'));
    }

    /**
     * A Multi-Company Split Awards award — a real Bid is a required FK on
     * job_awards, so one is created here rather than via a factory.
     */
    private function awardTo(Job $job, TransporterCompany $company, int $trucksOffered): JobAward
    {
        $bid = Bid::factory()->for($job)->for($company, 'company')->create(['trucks_offered' => $trucksOffered]);

        return JobAward::create([
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $company->id,
            'trucks_offered' => $trucksOffered,
            'agreed_price' => $bid->price,
        ]);
    }

    public function test_a_tier_3_award_still_open_at_the_job_level_counts_as_an_anchor(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $company = $companyUser->transporterCompany;

        // A Multi-Company Split Awards job: this company has an award on
        // it, but jobs.status is still 'open' since the rest of the job
        // isn't fully covered yet.
        $splitJob = Job::factory()->create(['status' => 'open', 'trucks_needed' => 5]);
        $this->awardTo($splitJob, $company, 2);

        $nearby = Job::factory()->create(['status' => 'open', 'budget_price' => 400000]);

        $response = $this->actingAs($companyUser)->getJson('/api/company/jobs/return-loads');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($nearby->id));
        // The split job itself is still 'open' — it must never match
        // itself as a return-load candidate.
        $this->assertFalse($ids->contains($splitJob->id));
    }

    public function test_the_anchor_job_itself_is_excluded_from_its_own_results(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $companyId = $companyUser->transporterCompany->id;

        // A Tier-3 award keeps a job 'open' — the only realistic case
        // where an anchor job could otherwise match itself.
        $anchor = Job::factory()->create(['status' => 'open', 'trucks_needed' => 5]);
        $this->awardTo($anchor, $companyUser->transporterCompany, 2);

        $response = $this->actingAs($companyUser)->getJson('/api/company/jobs/return-loads');

        $response->assertOk();
        $this->assertFalse(collect($response->json('data'))->pluck('id')->contains($anchor->id));
    }
}
