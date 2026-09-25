<?php

namespace Tests\Feature\Jobs;

use App\Models\Bid;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobEditTest extends TestCase
{
    use RefreshDatabase;

    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'pickup_address' => 'Kariakoo, Dar es Salaam',
            'pickup_lat' => -6.8161,
            'pickup_lng' => 39.2803,
            'dropoff_address' => 'Mbezi Beach, Dar es Salaam',
            'dropoff_lat' => -6.7,
            'dropoff_lng' => 39.2,
            'container_type' => 'Dry Van',
            'container_size' => '40ft',
            'trucks_needed' => 1,
            'budget_price' => 500000,
            'preferred_pickup_window_start' => now()->addDays(3)->toIso8601String(),
            'bidding_expires_at' => now()->addDays(2)->toIso8601String(),
        ], $overrides);
    }

    public function test_the_customer_can_edit_pickup_location_while_the_job_is_still_open(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);

        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}", $this->validPayload([
            'pickup_address' => 'Updated Pickup Address, Dar es Salaam',
            'pickup_lat' => -6.9,
            'pickup_lng' => 39.3,
        ]));

        $response->assertOk();
        $job->refresh();
        $this->assertSame('Updated Pickup Address, Dar es Salaam', $job->pickup_address);
        $updated = Job::withCoordinates()->findOrFail($job->id);
        $this->assertEqualsWithDelta(-6.9, $updated->pickup_lat, 0.0001);
        $this->assertEqualsWithDelta(39.3, $updated->pickup_lng, 0.0001);
    }

    public function test_cannot_edit_a_job_once_it_is_no_longer_open(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'assigned']);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}", $this->validPayload())
            ->assertUnprocessable()->assertJsonValidationErrors(['status']);
    }

    public function test_a_customer_cannot_edit_another_customers_job(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['status' => 'open']);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}", $this->validPayload())
            ->assertNotFound();
    }

    public function test_editing_the_pickup_location_withdraws_pending_bids_and_notifies_bidders(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create();
        $bid = Bid::factory()->for($job)->create(['transporter_company_id' => $company->id, 'status' => 'pending']);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}", $this->validPayload([
            'pickup_lat' => -6.95,
            'pickup_lng' => 39.35,
        ]))->assertOk();

        $this->assertSame('withdrawn', $bid->fresh()->status);
        $this->assertDatabaseHas('notifications', ['user_id' => $companyOwner->id, 'type' => 'bid_withdrawn']);
    }

    public function test_editing_without_actually_moving_the_pin_does_not_touch_pending_bids(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);
        $job = Job::withCoordinates()->findOrFail($job->id);
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create();
        $bid = Bid::factory()->for($job)->create(['transporter_company_id' => $company->id, 'status' => 'pending']);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}", $this->validPayload([
            'pickup_lat' => $job->pickup_lat,
            'pickup_lng' => $job->pickup_lng,
            'dropoff_lat' => $job->dropoff_lat,
            'dropoff_lng' => $job->dropoff_lng,
            'pickup_address' => $job->pickup_address,
            'dropoff_address' => $job->dropoff_address,
        ]))->assertOk();

        $this->assertSame('pending', $bid->fresh()->status);
        $this->assertDatabaseMissing('notifications', ['type' => 'bid_withdrawn']);
    }
}
