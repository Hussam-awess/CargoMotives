<?php

namespace Tests\Feature\Reviews;

use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * JobResource.reviewable/rated_by_viewer (Phase: ratings) — the flags the
 * app uses to show/hide the "Rate your experience" prompt, from each
 * participant's own point of view.
 */
class JobReviewableFlagsTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_job_not_yet_completed_is_never_reviewable(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'in_transit']);

        $response = $this->actingAs($customer)->getJson("/api/jobs/{$job->id}");

        $response->assertOk();
        $this->assertArrayNotHasKey('reviewable', $response->json('data'));
        $this->assertArrayNotHasKey('rated_by_viewer', $response->json('data'));
    }

    public function test_the_customer_sees_reviewable_true_before_rating_and_false_after(): void
    {
        $customer = User::factory()->create();
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $company->id, 'status' => 'completed']);

        $before = $this->actingAs($customer)->getJson("/api/jobs/{$job->id}");
        $before->assertOk()->assertJsonPath('data.reviewable', true)->assertJsonPath('data.rated_by_viewer', false);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 5])->assertCreated();

        $after = $this->actingAs($customer)->getJson("/api/jobs/{$job->id}");
        $after->assertOk()->assertJsonPath('data.reviewable', false)->assertJsonPath('data.rated_by_viewer', true);
    }

    public function test_the_transporter_sees_its_own_independent_reviewable_state(): void
    {
        $customer = User::factory()->create();
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $company->id, 'status' => 'completed']);

        // The customer rating first must not affect the transporter's own
        // still-unrated state — these are two independent one-per-rater
        // rows, not a shared flag.
        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 5])->assertCreated();

        $response = $this->actingAs($companyOwner)->getJson("/api/company/jobs/{$job->id}");
        $response->assertOk()->assertJsonPath('data.reviewable', true)->assertJsonPath('data.rated_by_viewer', false);

        $this->actingAs($companyOwner)->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 4])->assertCreated();

        $response = $this->actingAs($companyOwner)->getJson("/api/company/jobs/{$job->id}");
        $response->assertOk()->assertJsonPath('data.reviewable', false)->assertJsonPath('data.rated_by_viewer', true);
    }
}
