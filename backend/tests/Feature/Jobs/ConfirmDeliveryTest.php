<?php

namespace Tests\Feature\Jobs;

use App\Models\DriverLink;
use App\Models\Job;
use App\Models\ProofOfDelivery;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class ConfirmDeliveryTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_customer_can_confirm_receipt_once_delivered(): void
    {
        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        $job = Job::factory()->create([
            'customer_id' => $customer->id,
            'status' => 'delivered',
            'assigned_company_id' => $company->id,
            'assigned_truck_id' => $truck->id,
            'agreed_price' => 100000,
            'preferred_pickup_window_start' => Carbon::parse('2026-01-01 09:00:00'),
        ]);
        $link = DriverLink::factory()->used()->create(['job_id' => $job->id]);
        ProofOfDelivery::factory()->create(['job_id' => $job->id, 'driver_link_id' => $link->id]);

        Carbon::setTestNow(Carbon::parse('2026-09-21 14:32:00'));
        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/confirm-delivery");
        Carbon::setTestNow();

        $response->assertOk()->assertJsonPath('data.status', 'completed');
        $response->assertJsonPath('data.completed_at', '2026-09-21T14:32:00+00:00');

        $job->refresh();
        $this->assertSame('completed', $job->status);
        $this->assertSame('idle', $truck->fresh()->current_status);
        $this->assertNotNull($job->proofOfDelivery->confirmed_by_customer_at);
        // The real completion moment, never the originally scheduled
        // pickup window it started from.
        $this->assertTrue($job->completed_at->equalTo(Carbon::parse('2026-09-21 14:32:00')));
        $this->assertFalse($job->completed_at->equalTo($job->preferred_pickup_window_start));
    }

    public function test_completing_a_job_sends_a_rate_prompt_to_both_participants(): void
    {
        Queue::fake();

        $customer = User::factory()->create();
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create();
        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        $job = Job::factory()->create([
            'customer_id' => $customer->id,
            'status' => 'delivered',
            'assigned_company_id' => $company->id,
            'assigned_truck_id' => $truck->id,
        ]);
        $link = DriverLink::factory()->used()->create(['job_id' => $job->id]);
        ProofOfDelivery::factory()->create(['job_id' => $job->id, 'driver_link_id' => $link->id]);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/confirm-delivery")->assertOk();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $customer->id,
            'type' => 'job_completed_rate_prompt',
            'related_job_id' => $job->id,
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $companyOwner->id,
            'type' => 'job_completed_rate_prompt',
            'related_job_id' => $job->id,
        ]);
    }

    public function test_cannot_confirm_a_job_that_is_not_yet_delivered(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'in_transit']);

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/confirm-delivery")
            ->assertUnprocessable();
    }

    public function test_a_customer_cannot_confirm_another_customers_job(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['status' => 'delivered']);

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/confirm-delivery")
            ->assertNotFound();
    }
}
