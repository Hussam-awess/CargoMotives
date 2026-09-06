<?php

namespace Tests\Feature\Console;

use App\Models\Job;
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
}
