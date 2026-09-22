<?php

namespace Tests\Feature\Reviews;

use App\Models\Job;
use App\Models\JobReview;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobReviewTest extends TestCase
{
    use RefreshDatabase;

    private function completedJob(): array
    {
        $customer = User::factory()->create();
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create();
        $job = Job::factory()->create([
            'customer_id' => $customer->id,
            'assigned_company_id' => $company->id,
            'status' => 'completed',
        ]);

        return [$job, $customer, $companyOwner, $company];
    }

    public function test_a_customer_can_rate_the_transporter_on_a_completed_job(): void
    {
        [$job, $customer, , $company] = $this->completedJob();

        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/reviews", [
            'rating' => 5,
            'comment' => 'Great service, on time.',
            'category_ratings' => ['punctuality' => 5, 'vehicle_condition' => 4, 'professionalism' => 5],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.rater_type', 'customer')
            ->assertJsonPath('data.rating', 5)
            ->assertJsonPath('data.comment', 'Great service, on time.');

        $this->assertDatabaseHas('job_reviews', [
            'job_id' => $job->id,
            'rater_user_id' => $customer->id,
            'ratee_company_id' => $company->id,
            'ratee_customer_id' => null,
        ]);

        $company->refresh();
        $this->assertEquals(5.0, (float) $company->average_rating);
        $this->assertSame(1, $company->rating_count);
    }

    public function test_a_transporter_can_rate_the_customer_on_a_completed_job(): void
    {
        [$job, $customer, $companyOwner] = $this->completedJob();

        $response = $this->actingAs($companyOwner)->postJson("/api/jobs/{$job->id}/reviews", [
            'rating' => 4,
            'category_ratings' => ['communication' => 4, 'cargo_accuracy' => 5, 'payment_promptness' => 4],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.rater_type', 'transporter_company')
            ->assertJsonPath('data.rating', 4)
            ->assertJsonPath('data.comment', null);

        $this->assertDatabaseHas('job_reviews', [
            'job_id' => $job->id,
            'rater_user_id' => $companyOwner->id,
            'ratee_customer_id' => $customer->id,
            'ratee_company_id' => null,
        ]);

        $customer->refresh();
        $this->assertEquals(4.0, (float) $customer->average_rating);
        $this->assertSame(1, $customer->rating_count);
    }

    public function test_average_rating_is_a_real_average_across_multiple_reviews(): void
    {
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create();

        $jobOne = Job::factory()->create(['assigned_company_id' => $company->id, 'status' => 'completed']);
        $jobTwo = Job::factory()->create(['assigned_company_id' => $company->id, 'status' => 'completed']);

        $this->actingAs($jobOne->customer)->postJson("/api/jobs/{$jobOne->id}/reviews", ['rating' => 5])->assertCreated();
        $this->actingAs($jobTwo->customer)->postJson("/api/jobs/{$jobTwo->id}/reviews", ['rating' => 3])->assertCreated();

        $company->refresh();
        $this->assertEquals(4.0, (float) $company->average_rating);
        $this->assertSame(2, $company->rating_count);
    }

    public function test_cannot_rate_a_job_that_is_not_yet_completed(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'in_transit']);

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 5])
            ->assertUnprocessable();
    }

    public function test_cannot_rate_the_same_job_twice(): void
    {
        [$job, $customer] = $this->completedJob();

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 5])->assertCreated();

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 1])
            ->assertUnprocessable();

        $this->assertSame(1, JobReview::where('job_id', $job->id)->count());
    }

    /**
     * The real backstop for a genuine concurrent-submission race the
     * controller's own pre-check (test_cannot_rate_the_same_job_twice
     * above) can't fully close on its own — proves the unique index on
     * (job_id, rater_user_id) is actually in place and enforced at the
     * database level. A raw model save bypasses the controller on purpose
     * here; JobReviewController::store()'s own try/catch around this same
     * constraint is what turns it into a clean 422 instead of a raw 500
     * for a real double-tap.
     */
    public function test_the_database_itself_refuses_two_reviews_from_the_same_rater_on_the_same_job(): void
    {
        [$job, $customer] = $this->completedJob();
        JobReview::create(['job_id' => $job->id, 'rater_type' => 'customer', 'rater_user_id' => $customer->id, 'rating' => 5]);

        $this->expectException(QueryException::class);

        JobReview::create(['job_id' => $job->id, 'rater_type' => 'customer', 'rater_user_id' => $customer->id, 'rating' => 3]);
    }

    public function test_a_non_participant_cannot_rate_the_job(): void
    {
        [$job] = $this->completedJob();
        $stranger = User::factory()->create();

        $this->actingAs($stranger)
            ->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 5])
            ->assertNotFound();
    }

    public function test_rating_is_required_and_must_be_between_1_and_5(): void
    {
        [$job, $customer] = $this->completedJob();

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/reviews", [])->assertUnprocessable();
        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 6])->assertUnprocessable();
    }

    public function test_a_customer_cannot_submit_the_transporters_category_keys(): void
    {
        [$job, $customer] = $this->completedJob();

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 5, 'category_ratings' => ['communication' => 5]])
            ->assertUnprocessable();
    }

    public function test_a_written_comment_is_optional(): void
    {
        [$job, $customer] = $this->completedJob();

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 5])
            ->assertCreated()
            ->assertJsonPath('data.comment', null);
    }
}
