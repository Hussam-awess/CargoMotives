<?php

namespace Tests\Feature\Jobs;

use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

/**
 * See BidQuotaServiceTest's docblock: safe to flushdb() because
 * phpunit.xml isolates tests onto their own Redis logical database.
 */
class JobPostingTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Redis::flushdb();
        parent::tearDown();
    }

    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'pickup_address' => 'Dar es Salaam Port',
            'pickup_lat' => -6.8235,
            'pickup_lng' => 39.2695,
            'dropoff_address' => 'Mbeya, Tanzania',
            'dropoff_lat' => -8.9094,
            'dropoff_lng' => 33.4608,
            'container_type' => 'Dry Van',
            'container_size' => '40ft',
            'approx_weight_tons' => 15,
            'preferred_pickup_window_start' => now()->addDay()->toIso8601String(),
            'customer_notes' => 'Handle with care.',
        ], $overrides);
    }

    public function test_a_customer_can_post_a_job(): void
    {
        $customer = User::factory()->create();

        $response = $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload());

        $response->assertCreated()
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.pickup_address', 'Dar es Salaam Port')
            ->assertJsonPath('data.pickup_lat', -6.8235)
            ->assertJsonPath('data.dropoff_lng', 33.4608);

        $this->assertDatabaseHas('jobs', ['customer_id' => $customer->id, 'status' => 'open']);
    }

    public function test_a_customer_can_post_a_job_with_a_budget_price(): void
    {
        $customer = User::factory()->create();

        $response = $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload(['budget_price' => 850000]));

        $response->assertCreated()->assertJsonPath('data.budget_price', 850000);
    }

    public function test_a_customer_can_post_a_job_without_a_budget_price(): void
    {
        $customer = User::factory()->create();

        $response = $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload());

        $response->assertCreated()->assertJsonPath('data.budget_price', null);
    }

    public function test_a_company_cannot_post_a_job(): void
    {
        $company = User::factory()->transporterCompany()->create();

        $this->actingAs($company)->postJson('/api/jobs', $this->validPayload())->assertForbidden();
    }

    public function test_a_standard_customer_is_limited_to_5_posts_per_rolling_24h(): void
    {
        $customer = User::factory()->create();

        for ($i = 0; $i < 5; $i++) {
            $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload())->assertCreated();
        }

        $response = $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload());
        $response->assertStatus(429)->assertJsonStructure(['seconds_until_slot_frees']);
    }

    public function test_post_quota_endpoint_reports_remaining(): void
    {
        $customer = User::factory()->create();

        $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload());

        $this->actingAs($customer)
            ->getJson('/api/jobs/post-quota')
            ->assertOk()
            ->assertJsonPath('remaining', 4);
    }

    public function test_a_customer_can_only_see_their_own_jobs(): void
    {
        $customerA = User::factory()->create();
        $customerB = User::factory()->create();
        Job::factory()->create(['customer_id' => $customerA->id]);
        Job::factory()->create(['customer_id' => $customerB->id]);

        $response = $this->actingAs($customerA)->getJson('/api/jobs');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    public function test_a_customer_cannot_view_another_customers_job(): void
    {
        $customerA = User::factory()->create();
        $customerB = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customerB->id]);

        $this->actingAs($customerA)->getJson("/api/jobs/{$job->id}")->assertNotFound();
    }

    public function test_a_customer_can_edit_an_open_job(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'container_type' => 'Dry Van']);

        $response = $this->actingAs($customer)->postJson(
            "/api/jobs/{$job->id}",
            $this->validPayload(['container_type' => 'Reefer'])
        );

        $response->assertOk()->assertJsonPath('data.container_type', 'Reefer');
    }

    public function test_a_customer_cannot_edit_a_job_that_is_no_longer_open(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->assigned()->create(['customer_id' => $customer->id]);

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}", $this->validPayload())
            ->assertUnprocessable();
    }

    public function test_a_customer_can_cancel_an_open_job(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/cancel", [
            'reason' => 'Changed my mind.',
        ]);

        $response->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->assertDatabaseHas('jobs', ['id' => $job->id, 'cancelled_reason' => 'Changed my mind.']);
    }

    public function test_a_customer_cannot_cancel_an_assigned_job(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->assigned()->create(['customer_id' => $customer->id]);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/cancel")->assertUnprocessable();
    }
}
