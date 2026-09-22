<?php

namespace Tests\Feature\Console;

use App\Models\Bid;
use App\Models\Driver;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobTruckAssignment;
use App\Models\Truck;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CheckGpsSignalLossTest extends TestCase
{
    use RefreshDatabase;

    public function test_flips_a_trackable_job_to_lost_once_its_truck_has_gone_quiet(): void
    {
        config(['gps.signal_lost_after_minutes' => 10]);
        $truck = Truck::factory()->approved()->create(['last_known_at' => now()->subMinutes(15)]);
        $job = Job::factory()->create([
            'assigned_truck_id' => $truck->id,
            'gps_tracking_active' => true,
            'gps_signal_status' => 'ok',
        ]);

        $this->artisan('gps:check-signal-loss')->assertSuccessful();

        $this->assertSame('lost', $job->fresh()->gps_signal_status);
    }

    public function test_does_not_touch_a_job_whose_truck_is_still_reporting_recently(): void
    {
        config(['gps.signal_lost_after_minutes' => 10]);
        $truck = Truck::factory()->approved()->create(['last_known_at' => now()->subMinutes(2)]);
        $job = Job::factory()->create([
            'assigned_truck_id' => $truck->id,
            'gps_tracking_active' => true,
            'gps_signal_status' => 'ok',
        ]);

        $this->artisan('gps:check-signal-loss')->assertSuccessful();

        $this->assertSame('ok', $job->fresh()->gps_signal_status);
    }

    public function test_flips_a_job_whose_truck_never_sent_a_single_position_at_all(): void
    {
        // A Phase 10 audit gap: a truck marked GPS-connected at assignment
        // (gps_signal_status optimistically set to 'ok' — JobAssignmentService)
        // that then never sends one real position leaves last_known_at
        // NULL forever, which `last_known_at < cutoff` can never match
        // (SQL comparisons against NULL are neither true nor false). This
        // is exactly why gps_tracking_started_at exists.
        config(['gps.signal_lost_after_minutes' => 10]);
        $truck = Truck::factory()->approved()->create(['last_known_at' => null]);
        $job = Job::factory()->create([
            'assigned_truck_id' => $truck->id,
            'gps_tracking_active' => true,
            'gps_signal_status' => 'ok',
            'gps_tracking_started_at' => now()->subMinutes(15),
        ]);

        $this->artisan('gps:check-signal-loss')->assertSuccessful();

        $this->assertSame('lost', $job->fresh()->gps_signal_status);
    }

    public function test_does_not_touch_a_job_still_waiting_for_its_first_position_within_the_window(): void
    {
        config(['gps.signal_lost_after_minutes' => 10]);
        $truck = Truck::factory()->approved()->create(['last_known_at' => null]);
        $job = Job::factory()->create([
            'assigned_truck_id' => $truck->id,
            'gps_tracking_active' => true,
            'gps_signal_status' => 'ok',
            'gps_tracking_started_at' => now()->subMinutes(2),
        ]);

        $this->artisan('gps:check-signal-loss')->assertSuccessful();

        $this->assertSame('ok', $job->fresh()->gps_signal_status);
    }

    public function test_never_touches_a_job_with_no_gps_tracking_at_all(): void
    {
        $truck = Truck::factory()->approved()->create(['last_known_at' => null]);
        $job = Job::factory()->create([
            'assigned_truck_id' => $truck->id,
            'gps_tracking_active' => false,
            'gps_signal_status' => 'not_applicable',
        ]);

        $this->artisan('gps:check-signal-loss')->assertSuccessful();

        $this->assertSame('not_applicable', $job->fresh()->gps_signal_status);
    }

    public function test_does_not_re_flag_a_job_already_marked_lost(): void
    {
        config(['gps.signal_lost_after_minutes' => 10]);
        $truck = Truck::factory()->approved()->create(['last_known_at' => now()->subMinutes(30)]);
        Job::factory()->create([
            'assigned_truck_id' => $truck->id,
            'gps_tracking_active' => true,
            'gps_signal_status' => 'lost',
        ]);

        // Just confirms this doesn't error against an already-lost job —
        // recovery is NormalizeGpsPositionJob's job, not this sweep's.
        $this->artisan('gps:check-signal-loss')->assertSuccessful();
    }

    /**
     * Multi-Company Split Awards epic: a job with 2+ awards has no single
     * assignedTruck for the job-level sweep above to ever match — this
     * confirms the second, award-scoped sweep catches it independently.
     */
    public function test_flips_a_tier_3_awards_lead_truck_to_lost_once_it_has_gone_quiet(): void
    {
        config(['gps.signal_lost_after_minutes' => 10]);
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 20]);
        $bid = Bid::factory()->for($job)->create(['trucks_offered' => 8]);
        $award = JobAward::create([
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $bid->transporter_company_id,
            'trucks_offered' => 8,
            'agreed_price' => $bid->price,
            'gps_tracking_active' => true,
            'gps_signal_status' => 'ok',
        ]);
        $truck = Truck::factory()->approved()->create(['last_known_at' => now()->subMinutes(15)]);
        JobTruckAssignment::create([
            'job_id' => $job->id,
            'job_award_id' => $award->id,
            'truck_id' => $truck->id,
            'driver_id' => Driver::factory()->create()->id,
            'is_lead' => true,
            'assigned_at' => now(),
        ]);

        $this->artisan('gps:check-signal-loss')->assertSuccessful();

        $this->assertSame('lost', $award->fresh()->gps_signal_status);
        // The job itself is never touched by a Tier 3 award's own sweep.
        $this->assertSame('not_applicable', $job->fresh()->gps_signal_status);
    }
}
