<?php

namespace Tests\Feature\Jobs;

use App\Models\Driver;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use App\Services\Jobs\JobPostQuotaService;
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
            'trucks_needed' => 1,
            'approx_weight_tons' => 15,
            'budget_price' => 850000,
            'preferred_pickup_window_start' => now()->addDays(4)->toIso8601String(),
            'customer_notes' => 'Handle with care.',
            'bidding_expires_at' => now()->addDays(2)->toIso8601String(),
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

    public function test_a_customer_can_post_a_job_in_usd(): void
    {
        $customer = User::factory()->create();

        $response = $this->actingAs($customer)->postJson(
            '/api/jobs',
            $this->validPayload(['currency' => 'USD', 'budget_price' => 1200]),
        );

        $response->assertCreated()
            ->assertJsonPath('data.currency', 'USD')
            ->assertJsonPath('data.budget_price', 1200);
    }

    /**
     * An older client (or one that simply omits the field) falls back to
     * whatever the customer already chose in Settings — never silently
     * TZS regardless of that preference.
     */
    public function test_omitting_currency_defaults_to_the_customers_own_preference(): void
    {
        $customer = User::factory()->create(['preferred_currency' => 'USD']);

        $response = $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload(['budget_price' => 1200]));

        $response->assertCreated()->assertJsonPath('data.currency', 'USD');
    }

    public function test_a_usd_budget_outside_the_usd_bounds_is_rejected(): void
    {
        $customer = User::factory()->create();

        // A TZS-scaled figure is wildly out of range once labeled USD.
        $this->actingAs($customer)
            ->postJson('/api/jobs', $this->validPayload(['currency' => 'USD', 'budget_price' => 850000]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('budget_price');
    }

    public function test_an_unsupported_currency_is_rejected(): void
    {
        $customer = User::factory()->create();

        $this->actingAs($customer)
            ->postJson('/api/jobs', $this->validPayload(['currency' => 'EUR']))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('currency');
    }

    public function test_a_customer_can_post_a_bulk_cargo_job_needing_many_trucks(): void
    {
        $customer = User::factory()->create();

        $response = $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload(['trucks_needed' => 20]));

        $response->assertCreated()->assertJsonPath('data.trucks_needed', 20);
    }

    public function test_a_customer_must_provide_a_trucks_needed_count_to_post_a_job(): void
    {
        $customer = User::factory()->create();

        $payload = $this->validPayload();
        unset($payload['trucks_needed']);

        $response = $this->actingAs($customer)->postJson('/api/jobs', $payload);

        $response->assertUnprocessable()->assertJsonValidationErrors('trucks_needed');
    }

    public function test_a_customer_must_provide_a_budget_price_to_post_a_job(): void
    {
        $customer = User::factory()->create();

        $payload = $this->validPayload();
        unset($payload['budget_price']);

        $response = $this->actingAs($customer)->postJson('/api/jobs', $payload);

        $response->assertUnprocessable()->assertJsonValidationErrors('budget_price');
    }

    public function test_a_customer_must_provide_a_bidding_deadline_to_post_a_job(): void
    {
        $customer = User::factory()->create();

        $payload = $this->validPayload();
        unset($payload['bidding_expires_at']);

        $response = $this->actingAs($customer)->postJson('/api/jobs', $payload);

        $response->assertUnprocessable()->assertJsonValidationErrors('bidding_expires_at');
    }

    public function test_a_bidding_deadline_must_be_before_the_pickup_window(): void
    {
        $customer = User::factory()->create();

        $payload = $this->validPayload([
            'preferred_pickup_window_start' => now()->addDays(2)->toIso8601String(),
            'bidding_expires_at' => now()->addDays(3)->toIso8601String(),
        ]);

        $response = $this->actingAs($customer)->postJson('/api/jobs', $payload);

        $response->assertUnprocessable()->assertJsonValidationErrors('bidding_expires_at');
    }

    public function test_a_bidding_deadline_cannot_be_sooner_than_the_configured_minimum(): void
    {
        config(['bidding.min_days' => 1]);
        $customer = User::factory()->create();

        $payload = $this->validPayload(['bidding_expires_at' => now()->addHours(2)->toIso8601String()]);

        $response = $this->actingAs($customer)->postJson('/api/jobs', $payload);

        $response->assertUnprocessable()->assertJsonValidationErrors('bidding_expires_at');
    }

    public function test_a_bidding_deadline_cannot_be_further_out_than_the_configured_maximum(): void
    {
        config(['bidding.max_days' => 7]);
        $customer = User::factory()->create();

        $payload = $this->validPayload([
            'preferred_pickup_window_start' => now()->addDays(10)->toIso8601String(),
            'bidding_expires_at' => now()->addDays(9)->toIso8601String(),
        ]);

        $response = $this->actingAs($customer)->postJson('/api/jobs', $payload);

        $response->assertUnprocessable()->assertJsonValidationErrors('bidding_expires_at');
    }

    public function test_a_bidding_deadline_within_bounds_is_accepted(): void
    {
        $customer = User::factory()->create();

        $payload = $this->validPayload([
            'preferred_pickup_window_start' => now()->addDays(8)->toIso8601String(),
            'bidding_expires_at' => now()->addDays(7)->subHour()->toIso8601String(),
        ]);

        $response = $this->actingAs($customer)->postJson('/api/jobs', $payload);

        $response->assertCreated();
        $this->assertNotNull($response->json('data.bidding_expires_at'));
    }

    public function test_a_company_cannot_post_a_job(): void
    {
        $company = User::factory()->transporterCompany()->create();

        $this->actingAs($company)->postJson('/api/jobs', $this->validPayload())->assertForbidden();
    }

    public function test_a_standard_customer_is_limited_to_10_posts_per_rolling_24h(): void
    {
        $customer = User::factory()->create();

        for ($i = 0; $i < 10; $i++) {
            $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload())->assertCreated();
        }

        $response = $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload());
        $response->assertStatus(429)->assertJsonStructure(['seconds_until_slot_frees']);
    }

    /**
     * Cargo Motives Plus: no post limit at all, not just a higher one.
     */
    public function test_a_featured_customer_has_no_post_limit(): void
    {
        $customer = User::factory()->create(['is_featured' => true]);

        for ($i = 0; $i < 25; $i++) {
            $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload())->assertCreated();
        }
    }

    public function test_post_quota_endpoint_reports_remaining(): void
    {
        $customer = User::factory()->create();

        $this->actingAs($customer)->postJson('/api/jobs', $this->validPayload());

        $this->actingAs($customer)
            ->getJson('/api/jobs/post-quota')
            ->assertOk()
            ->assertJsonPath('remaining', 9);
    }

    public function test_post_quota_endpoint_reports_unlimited_for_a_featured_customer(): void
    {
        $customer = User::factory()->create(['is_featured' => true]);

        $this->actingAs($customer)
            ->getJson('/api/jobs/post-quota')
            ->assertOk()
            ->assertJsonPath('remaining', JobPostQuotaService::UNLIMITED);
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

    public function test_a_customers_job_view_shows_the_assigned_companys_name_and_id_on_show_and_index(): void
    {
        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create(['company_name' => 'ABC Logistics']);
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $company->id, 'status' => 'assigned']);

        $this->actingAs($customer)
            ->getJson("/api/jobs/{$job->id}")
            ->assertOk()
            ->assertJsonPath('data.assigned_company_id', $company->id)
            ->assertJsonPath('data.assigned_company_name', 'ABC Logistics');

        $this->actingAs($customer)
            ->getJson('/api/jobs')
            ->assertOk()
            ->assertJsonPath('data.0.assigned_company_id', $company->id)
            ->assertJsonPath('data.0.assigned_company_name', 'ABC Logistics');
    }

    /**
     * Regression test: assignedDriver wasn't eager-loaded on index(), so
     * JobResource::assigned_driver_name's whenLoaded() silently omitted
     * the field on the customer's own job list — the Messages inbox (which
     * shows the assigned driver's name alongside the company) had nothing
     * to show even for a job that has one.
     */
    public function test_a_customers_job_list_shows_the_assigned_drivers_name(): void
    {
        $customer = User::factory()->create();
        $driver = Driver::factory()->create(['full_name' => 'Juma Hassan']);
        $job = Job::factory()->create([
            'customer_id' => $customer->id,
            'assigned_driver_id' => $driver->id,
            'status' => 'assigned',
        ]);

        $this->actingAs($customer)
            ->getJson('/api/jobs')
            ->assertOk()
            ->assertJsonPath('data.0.id', $job->id)
            ->assertJsonPath('data.0.assigned_driver_name', 'Juma Hassan');
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

    /**
     * Currency is set once, at creation — editing can't change it out from
     * under an already-placed bid denominated in the original currency.
     */
    public function test_editing_a_job_cannot_change_its_currency(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'currency' => 'TZS', 'budget_price' => 850000]);

        $response = $this->actingAs($customer)->postJson(
            "/api/jobs/{$job->id}",
            $this->validPayload(['currency' => 'USD', 'budget_price' => 1200]),
        );

        $response->assertOk()->assertJsonPath('data.currency', 'TZS');
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
