<?php

namespace Tests\Feature\Jobs;

use App\Models\DriverLink;
use App\Models\Job;
use App\Models\ProofOfDelivery;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
        ]);
        $link = DriverLink::factory()->used()->create(['job_id' => $job->id]);
        ProofOfDelivery::factory()->create(['job_id' => $job->id, 'driver_link_id' => $link->id]);

        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/confirm-delivery");

        $response->assertOk()->assertJsonPath('data.status', 'completed');

        $job->refresh();
        $this->assertSame('completed', $job->status);
        $this->assertSame('idle', $truck->fresh()->current_status);
        $this->assertNotNull($job->proofOfDelivery->confirmed_by_customer_at);
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
