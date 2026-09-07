<?php

namespace Tests\Feature\Jobs;

use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportProblemTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_customer_can_report_a_problem_once_delivered(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'delivered']);

        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/report-problem", [
            'reason' => 'The container arrived with visible damage to the seal.',
        ]);

        $response->assertCreated()->assertJsonPath('data.status', 'open');
        $this->assertDatabaseHas('disputes', [
            'job_id' => $job->id,
            'raised_by_user_id' => $customer->id,
            'status' => 'open',
        ]);
        // The job's own status is untouched — a dispute is a parallel
        // review process, not a job state (see JobController::reportProblem).
        $this->assertSame('delivered', $job->fresh()->status);
        $this->assertDatabaseHas('activity_logs', ['action' => 'dispute_raised']);
    }

    public function test_cannot_report_a_problem_before_delivery(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'in_transit']);

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/report-problem", ['reason' => 'Truck is nowhere to be seen.'])
            ->assertUnprocessable();
    }

    public function test_cannot_report_a_problem_twice_while_one_is_already_under_review(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'delivered']);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/report-problem", [
            'reason' => 'The container arrived with visible damage to the seal.',
        ])->assertCreated();

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/report-problem", ['reason' => 'Also the paperwork is wrong.'])
            ->assertUnprocessable();
    }

    public function test_a_customer_cannot_report_a_problem_on_another_customers_job(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['status' => 'delivered']);

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/report-problem", ['reason' => 'This is not even my job.'])
            ->assertNotFound();
    }
}
