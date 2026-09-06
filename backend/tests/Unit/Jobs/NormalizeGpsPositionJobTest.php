<?php

namespace Tests\Unit\Jobs;

use App\Events\TruckLocationUpdated;
use App\Jobs\NormalizeGpsPositionJob;
use App\Models\Job;
use App\Models\JobLocationSnapshot;
use App\Models\Truck;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * The "normalizer job" stage of the async GPS pipeline (TRD §5.2). See
 * BidBroadcastTest's docblock for why broadcast tests fake the event
 * rather than a live socket, and JobLocationChannelTest for the
 * authorization side of the channel this broadcasts to.
 */
class NormalizeGpsPositionJobTest extends TestCase
{
    use RefreshDatabase;

    public function test_updates_the_trucks_last_known_position_and_recovers_from_signal_lost(): void
    {
        $truck = Truck::factory()->approved()->create(['gps_status' => 'signal_lost', 'current_status' => 'idle']);
        $recordedAt = CarbonImmutable::now();

        (new NormalizeGpsPositionJob($truck->id, -6.8161, 39.2803, 90.0, $recordedAt))->handle();

        $truck->refresh();
        $this->assertSame('connected', $truck->gps_status);
        $this->assertEqualsWithDelta(-6.8161, (float) $truck->last_known_lat, 0.0001);
        $this->assertEqualsWithDelta(39.2803, (float) $truck->last_known_lng, 0.0001);
        $this->assertEqualsWithDelta(90.0, (float) $truck->last_known_heading, 0.0001);
        // The DB column stores whole-second precision (no fractional
        // seconds), so up to ~1s of rounding versus the microsecond-
        // precision Carbon instance we passed in is expected, not a bug.
        $this->assertLessThanOrEqual(1, abs($recordedAt->diffInSeconds($truck->last_known_at, false)));
    }

    public function test_ignores_a_position_no_newer_than_what_is_already_stored(): void
    {
        $staleTime = CarbonImmutable::now()->subMinutes(10);
        $truck = Truck::factory()->approved()->create([
            'last_known_lat' => -6.0, 'last_known_lng' => 39.0, 'last_known_at' => $staleTime,
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.9, 39.9, null, $staleTime->subMinute()))->handle();

        $truck->refresh();
        $this->assertEqualsWithDelta(-6.0, (float) $truck->last_known_lat, 0.0001);
    }

    public function test_broadcasts_and_snapshots_when_the_truck_is_on_a_trackable_job(): void
    {
        Event::fake([TruckLocationUpdated::class]);

        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        $job = Job::factory()->create(['assigned_truck_id' => $truck->id, 'status' => 'in_transit', 'gps_tracking_active' => true]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, CarbonImmutable::now()))->handle();

        Event::assertDispatched(TruckLocationUpdated::class, fn (TruckLocationUpdated $e) => $e->job->id === $job->id && $e->truck->id === $truck->id);
        $this->assertSame(1, JobLocationSnapshot::where('job_id', $job->id)->count());
        $this->assertSame('ok', $job->fresh()->gps_signal_status);
    }

    public function test_does_not_broadcast_when_the_truck_is_not_on_any_trackable_job(): void
    {
        Event::fake([TruckLocationUpdated::class]);

        $truck = Truck::factory()->approved()->create(['current_status' => 'idle']);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, CarbonImmutable::now()))->handle();

        Event::assertNotDispatched(TruckLocationUpdated::class);
    }

    public function test_throttles_snapshots_within_the_configured_window(): void
    {
        Event::fake([TruckLocationUpdated::class]);
        config(['gps.snapshot_throttle_minutes' => 5]);

        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        $job = Job::factory()->create(['assigned_truck_id' => $truck->id, 'status' => 'in_transit', 'gps_tracking_active' => true]);
        $now = CarbonImmutable::now();

        (new NormalizeGpsPositionJob($truck->id, -6.80, 39.20, null, $now))->handle();
        (new NormalizeGpsPositionJob($truck->id, -6.81, 39.21, null, $now->addMinutes(2)))->handle();

        $this->assertSame(1, JobLocationSnapshot::where('job_id', $job->id)->count());

        (new NormalizeGpsPositionJob($truck->id, -6.82, 39.22, null, $now->addMinutes(6)))->handle();

        $this->assertSame(2, JobLocationSnapshot::where('job_id', $job->id)->count());
    }

    public function test_a_missing_truck_is_a_no_op(): void
    {
        Event::fake([TruckLocationUpdated::class]);

        (new NormalizeGpsPositionJob(999999, -6.8, 39.2, null, CarbonImmutable::now()))->handle();

        Event::assertNotDispatched(TruckLocationUpdated::class);
    }
}
