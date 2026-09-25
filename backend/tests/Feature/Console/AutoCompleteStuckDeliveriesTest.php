<?php

namespace Tests\Feature\Console;

use App\Models\Bid;
use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobTruckAssignment;
use App\Models\ProofOfDelivery;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AutoCompleteStuckDeliveriesTest extends TestCase
{
    use RefreshDatabase;

    public function test_auto_completes_a_job_past_the_grace_period_with_a_permit_attached(): void
    {
        config(['gps.auto_complete_grace_period_hours' => 3]);
        $customer = User::factory()->create();
        $job = Job::factory()->assigned()->create([
            'customer_id' => $customer->id,
            'status' => 'in_transit',
            'dropoff_permit_path' => 'jobs/permits/1/test.pdf',
            'dropoff_arrival_notified_at' => now()->subHours(4),
        ]);
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $this->artisan('jobs:auto-complete-stuck-deliveries')->assertSuccessful();

        $job->refresh();
        $this->assertSame('delivered', $job->status);
        $this->assertDatabaseHas('proof_of_deliveries', [
            'job_id' => $job->id, 'driver_link_id' => $link->id, 'is_system_generated' => true,
        ]);
        $this->assertSame('used', $link->fresh()->status);
        $this->assertDatabaseHas('notifications', ['user_id' => $customer->id, 'type' => 'job_auto_completed']);
    }

    public function test_does_not_touch_a_job_still_within_the_grace_period(): void
    {
        config(['gps.auto_complete_grace_period_hours' => 3]);
        $job = Job::factory()->assigned()->create([
            'status' => 'in_transit',
            'dropoff_permit_path' => 'jobs/permits/1/test.pdf',
            'dropoff_arrival_notified_at' => now()->subHours(1),
        ]);
        DriverLink::factory()->create(['job_id' => $job->id]);

        $this->artisan('jobs:auto-complete-stuck-deliveries')->assertSuccessful();

        $this->assertSame('in_transit', $job->fresh()->status);
    }

    public function test_does_not_touch_a_job_with_no_dropoff_permit_attached(): void
    {
        config(['gps.auto_complete_grace_period_hours' => 3]);
        $job = Job::factory()->assigned()->create([
            'status' => 'in_transit',
            'dropoff_arrival_notified_at' => now()->subHours(10),
        ]);
        DriverLink::factory()->create(['job_id' => $job->id]);

        $this->artisan('jobs:auto-complete-stuck-deliveries')->assertSuccessful();

        $this->assertSame('in_transit', $job->fresh()->status);
    }

    public function test_does_not_touch_a_job_gps_never_confirmed_arrival_for(): void
    {
        config(['gps.auto_complete_grace_period_hours' => 3]);
        $job = Job::factory()->assigned()->create([
            'status' => 'in_transit',
            'dropoff_permit_path' => 'jobs/permits/1/test.pdf',
            'dropoff_arrival_notified_at' => null,
        ]);
        DriverLink::factory()->create(['job_id' => $job->id]);

        $this->artisan('jobs:auto-complete-stuck-deliveries')->assertSuccessful();

        $this->assertSame('in_transit', $job->fresh()->status);
    }

    public function test_skips_a_job_with_no_driver_link_ever_created(): void
    {
        config(['gps.auto_complete_grace_period_hours' => 3]);
        $job = Job::factory()->assigned()->create([
            'status' => 'in_transit',
            'dropoff_permit_path' => 'jobs/permits/1/test.pdf',
            'dropoff_arrival_notified_at' => now()->subHours(10),
        ]);

        // Confirms it doesn't error trying to fabricate a driver_id.
        $this->artisan('jobs:auto-complete-stuck-deliveries')->assertSuccessful();

        $this->assertSame('in_transit', $job->fresh()->status);
        $this->assertSame(0, ProofOfDelivery::count());
    }

    /**
     * Mirrors JobStatusAutoAdvancerTest's award-independence tests — a
     * Tier 3 award's own timer/status is independent of the job's, and the
     * drop-off permit itself stays job-level (see the permit migrations).
     */
    public function test_auto_completes_an_awards_own_stuck_delivery_independently_of_the_job(): void
    {
        config(['gps.auto_complete_grace_period_hours' => 3]);
        $job = Job::factory()->create([
            'status' => 'open', 'trucks_needed' => 20, 'dropoff_permit_path' => 'jobs/permits/1/test.pdf',
        ]);
        $bid = Bid::factory()->for($job)->create(['trucks_offered' => 8]);
        $award = JobAward::create([
            'job_id' => $job->id, 'bid_id' => $bid->id, 'transporter_company_id' => $bid->transporter_company_id,
            'trucks_offered' => 8, 'agreed_price' => $bid->price, 'status' => 'in_transit',
        ]);
        // dropoff_arrival_notified_at is system-set only (not in JobAward's
        // #[Fillable]) — forceFill it directly, same as JobStatusAutoAdvancer
        // itself does.
        $award->forceFill(['dropoff_arrival_notified_at' => now()->subHours(5)])->save();
        $truck = Truck::factory()->approved()->create();
        $driver = Driver::factory()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);
        JobTruckAssignment::create([
            'job_id' => $job->id, 'job_award_id' => $award->id, 'truck_id' => $truck->id,
            'driver_id' => $driver->id, 'driver_link_id' => $link->id, 'is_lead' => true, 'assigned_at' => now(),
        ]);

        $this->artisan('jobs:auto-complete-stuck-deliveries')->assertSuccessful();

        $this->assertSame('delivered', $award->fresh()->status);
        $this->assertSame('open', $job->fresh()->status);
        $this->assertDatabaseHas('proof_of_deliveries', ['job_award_id' => $award->id, 'is_system_generated' => true]);
    }
}
