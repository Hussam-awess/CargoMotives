<?php

namespace Tests\Unit\Jobs;

use App\Events\AwardLocationUpdated;
use App\Events\TruckLocationUpdated;
use App\Jobs\NormalizeGpsPositionJob;
use App\Models\Bid;
use App\Models\Driver;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobLocationSnapshot;
use App\Models\JobTruckAssignment;
use App\Models\Notification;
use App\Models\Truck;
use App\Models\User;
use App\Services\Geo\GeoPoint;
use App\Services\Jobs\JobStatusAutoAdvancer;
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

        (new NormalizeGpsPositionJob($truck->id, -6.8161, 39.2803, 90.0, $recordedAt, 62.5))->handle(app(JobStatusAutoAdvancer::class));

        $truck->refresh();
        $this->assertSame('connected', $truck->gps_status);
        $this->assertEqualsWithDelta(-6.8161, (float) $truck->last_known_lat, 0.0001);
        $this->assertEqualsWithDelta(39.2803, (float) $truck->last_known_lng, 0.0001);
        $this->assertEqualsWithDelta(90.0, (float) $truck->last_known_heading, 0.0001);
        $this->assertEqualsWithDelta(62.5, (float) $truck->last_known_speed_kmh, 0.0001);
        // The DB column stores whole-second precision (no fractional
        // seconds), so up to ~1s of rounding versus the microsecond-
        // precision Carbon instance we passed in is expected, not a bug.
        $this->assertLessThanOrEqual(1, abs($recordedAt->diffInSeconds($truck->last_known_at, false)));
    }

    public function test_updates_the_trucks_gps_reported_driver_name_when_given(): void
    {
        $truck = Truck::factory()->approved()->create(['gps_driver_name' => null]);

        (new NormalizeGpsPositionJob($truck->id, -6.8161, 39.2803, null, CarbonImmutable::now(), null, 'JOSEFAT MGOSI'))->handle(app(JobStatusAutoAdvancer::class));

        $this->assertSame('JOSEFAT MGOSI', $truck->fresh()->gps_driver_name);
    }

    public function test_ignores_a_position_no_newer_than_what_is_already_stored(): void
    {
        $staleTime = CarbonImmutable::now()->subMinutes(10);
        $truck = Truck::factory()->approved()->create([
            'last_known_lat' => -6.0, 'last_known_lng' => 39.0, 'last_known_at' => $staleTime,
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.9, 39.9, null, $staleTime->subMinute()))->handle(app(JobStatusAutoAdvancer::class));

        $truck->refresh();
        $this->assertEqualsWithDelta(-6.0, (float) $truck->last_known_lat, 0.0001);
    }

    public function test_broadcasts_and_snapshots_when_the_truck_is_on_a_trackable_job(): void
    {
        Event::fake([TruckLocationUpdated::class]);

        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        $job = Job::factory()->create(['assigned_truck_id' => $truck->id, 'status' => 'in_transit', 'gps_tracking_active' => true]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, CarbonImmutable::now()))->handle(app(JobStatusAutoAdvancer::class));

        Event::assertDispatched(TruckLocationUpdated::class, fn (TruckLocationUpdated $e) => $e->job->id === $job->id && $e->truck->id === $truck->id);
        $this->assertSame(1, JobLocationSnapshot::where('job_id', $job->id)->count());
        $this->assertSame('ok', $job->fresh()->gps_signal_status);
    }

    public function test_does_not_broadcast_when_the_truck_is_not_on_any_trackable_job(): void
    {
        Event::fake([TruckLocationUpdated::class]);

        $truck = Truck::factory()->approved()->create(['current_status' => 'idle']);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, CarbonImmutable::now()))->handle(app(JobStatusAutoAdvancer::class));

        Event::assertNotDispatched(TruckLocationUpdated::class);
    }

    public function test_throttles_snapshots_within_the_configured_window(): void
    {
        Event::fake([TruckLocationUpdated::class]);
        config(['gps.snapshot_throttle_minutes' => 5]);

        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        $job = Job::factory()->create(['assigned_truck_id' => $truck->id, 'status' => 'in_transit', 'gps_tracking_active' => true]);
        $now = CarbonImmutable::now();

        (new NormalizeGpsPositionJob($truck->id, -6.80, 39.20, null, $now))->handle(app(JobStatusAutoAdvancer::class));
        (new NormalizeGpsPositionJob($truck->id, -6.81, 39.21, null, $now->addMinutes(2)))->handle(app(JobStatusAutoAdvancer::class));

        $this->assertSame(1, JobLocationSnapshot::where('job_id', $job->id)->count());

        (new NormalizeGpsPositionJob($truck->id, -6.82, 39.22, null, $now->addMinutes(6)))->handle(app(JobStatusAutoAdvancer::class));

        $this->assertSame(2, JobLocationSnapshot::where('job_id', $job->id)->count());
    }

    /**
     * The real, confirmed bug this fixes: a device is mislabeled at the
     * source (Tracksolid's own record for this IMEI still says driver
     * "SULE" when the real driver is "Paulo") — every poll used to
     * unconditionally overwrite gps_driver_name, so a manual correction
     * never survived past the very next minute's poll.
     */
    public function test_a_manually_corrected_driver_name_survives_a_poll_that_repeats_the_same_stale_raw_value(): void
    {
        $truck = Truck::factory()->approved()->create([
            'gps_driver_name' => 'Paulo', 'gps_raw_driver_name' => 'SULE',
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, null, CarbonImmutable::now(), null, 'SULE'))->handle(app(JobStatusAutoAdvancer::class));

        $this->assertSame('Paulo', $truck->fresh()->gps_driver_name);
    }

    public function test_a_manual_correction_is_superseded_once_the_providers_raw_value_actually_changes(): void
    {
        $truck = Truck::factory()->approved()->create([
            'gps_driver_name' => 'Paulo', 'gps_raw_driver_name' => 'SULE',
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, null, CarbonImmutable::now(), null, 'A New Real Driver'))->handle(app(JobStatusAutoAdvancer::class));

        $truck->refresh();
        $this->assertSame('A New Real Driver', $truck->gps_driver_name);
        $this->assertSame('A New Real Driver', $truck->gps_raw_driver_name);
    }

    public function test_marks_stationary_since_on_the_first_slow_ping(): void
    {
        config(['gps.stationary_speed_threshold_kmh' => 3]);
        $truck = Truck::factory()->approved()->create(['stationary_since' => null]);
        $recordedAt = CarbonImmutable::now();

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, null, $recordedAt, 1.5))->handle(app(JobStatusAutoAdvancer::class));

        $truck->refresh();
        $this->assertNotNull($truck->stationary_since);
        $this->assertLessThanOrEqual(1, abs($recordedAt->diffInSeconds($truck->stationary_since, false)));
    }

    public function test_keeps_the_original_stationary_since_across_repeated_slow_pings(): void
    {
        config(['gps.stationary_speed_threshold_kmh' => 3]);
        $firstSlowAt = CarbonImmutable::now()->subMinutes(10);
        $truck = Truck::factory()->approved()->create([
            'last_known_at' => $firstSlowAt, 'stationary_since' => $firstSlowAt,
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, null, $firstSlowAt->addMinutes(2), 0.5))->handle(app(JobStatusAutoAdvancer::class));

        // Whole-second DB precision vs. the microsecond-precision Carbon
        // instance we seeded with — see the sibling position-timestamp
        // test's own comment on this exact rounding.
        $this->assertLessThanOrEqual(1, abs($firstSlowAt->diffInSeconds($truck->fresh()->stationary_since, false)));
    }

    public function test_clears_stationary_since_once_speed_rises_above_the_threshold(): void
    {
        config(['gps.stationary_speed_threshold_kmh' => 3]);
        $truck = Truck::factory()->approved()->create([
            'last_known_at' => CarbonImmutable::now()->subMinutes(5),
            'stationary_since' => CarbonImmutable::now()->subMinutes(5),
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, null, CarbonImmutable::now(), 40.0))->handle(app(JobStatusAutoAdvancer::class));

        $this->assertNull($truck->fresh()->stationary_since);
    }

    public function test_a_missing_truck_is_a_no_op(): void
    {
        Event::fake([TruckLocationUpdated::class]);

        (new NormalizeGpsPositionJob(999999, -6.8, 39.2, null, CarbonImmutable::now()))->handle(app(JobStatusAutoAdvancer::class));

        Event::assertNotDispatched(TruckLocationUpdated::class);
    }

    /**
     * Multi-Company Split Awards epic: the fix for the silent-GPS-death
     * bug — a Tier 3 job never sets assigned_truck_id (there's no single
     * "the" company), so the job-level lookup above finds nothing for one
     * of its awards' lead trucks. Without the fallback below, this truck's
     * position would update on the Truck row but never broadcast or
     * snapshot anywhere, with no error to reveal it.
     */
    public function test_broadcasts_and_snapshots_for_a_tier_3_awards_lead_truck(): void
    {
        Event::fake([AwardLocationUpdated::class, TruckLocationUpdated::class]);

        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 20]);
        $bid = Bid::factory()->for($job)->create(['trucks_offered' => 8]);
        $award = JobAward::create([
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $bid->transporter_company_id,
            'trucks_offered' => 8,
            'agreed_price' => $bid->price,
        ]);
        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        JobTruckAssignment::create([
            'job_id' => $job->id,
            'job_award_id' => $award->id,
            'truck_id' => $truck->id,
            'driver_id' => Driver::factory()->create()->id,
            'is_lead' => true,
            'assigned_at' => now(),
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, CarbonImmutable::now()))->handle(app(JobStatusAutoAdvancer::class));

        Event::assertDispatched(AwardLocationUpdated::class, fn (AwardLocationUpdated $e) => $e->award->id === $award->id && $e->truck->id === $truck->id);
        Event::assertNotDispatched(TruckLocationUpdated::class);
        $this->assertSame(1, JobLocationSnapshot::where('job_award_id', $award->id)->count());
        $this->assertSame('ok', $award->fresh()->gps_signal_status);
        $this->assertTrue((bool) $award->fresh()->gps_tracking_active);
        // The job-level fields are never touched by a Tier 3 award.
        $this->assertFalse((bool) $job->fresh()->gps_tracking_active);
    }

    /**
     * Confirms JobStatusAutoAdvancer is actually wired in with real
     * pickup/dropoff coordinates from the job — JobStatusAutoAdvancerTest
     * covers the geofencing logic itself in isolation; this is the
     * integration point that a naive version of this would get wrong
     * (e.g. forgetting Job::withCoordinates(), which would silently leave
     * pickup_lat/lng null and break every distance check).
     */
    public function test_the_status_advancer_runs_for_a_tier_1_job(): void
    {
        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        $job = Job::factory()->create(['assigned_truck_id' => $truck->id, 'status' => 'assigned']);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, CarbonImmutable::now()))->handle(app(JobStatusAutoAdvancer::class));

        $this->assertSame('en_route_pickup', $job->fresh()->status);
    }

    /**
     * The real, live-discovered bug this fixes: a real Tracksolid device
     * on a genuinely parked truck kept returning the exact same
     * last-known fix on every poll, so the "not newer than stored" guard
     * silently blocked JobStatusAutoAdvancer from ever running — the job
     * stayed stuck on 'assigned' forever, even though
     * JobStatusAutoAdvancer's own docblock says the mere presence of a
     * ping (no distance check) should be enough to advance it. Status
     * advancement must run off the poll's own reported position
     * regardless of whether that position is "new" — only the
     * telemetry/display fields (last_known_at etc.) stay gated on that.
     */
    public function test_status_still_advances_on_a_repeated_stale_position(): void
    {
        $staleTime = CarbonImmutable::now()->subMinutes(20);
        $truck = Truck::factory()->approved()->create([
            'current_status' => 'on_job',
            'last_known_lat' => -6.8, 'last_known_lng' => 39.2, 'last_known_at' => $staleTime,
        ]);
        $job = Job::factory()->create(['assigned_truck_id' => $truck->id, 'status' => 'assigned']);

        // The provider keeps re-returning the exact same fix — recordedAt
        // is not newer than what's already stored on the truck. Strictly
        // earlier (not just equal), same as test_ignores_a_position_no_
        // newer_than_what_is_already_stored, to sidestep the DB column's
        // whole-second precision rounding down a same-instant comparison.
        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, $staleTime->subMinute()))->handle(app(JobStatusAutoAdvancer::class));

        $this->assertSame('en_route_pickup', $job->fresh()->status);
    }

    /**
     * The flip side of the fix above: a repeated stale position must
     * still leave the telemetry/display fields and signal-recovery alone
     * — only status advancement is exempt from the freshness guard.
     */
    public function test_a_repeated_stale_position_does_not_touch_telemetry_signal_or_broadcast(): void
    {
        Event::fake([TruckLocationUpdated::class]);
        $staleTime = CarbonImmutable::now()->subMinutes(20);
        $truck = Truck::factory()->approved()->create([
            'current_status' => 'on_job',
            'last_known_lat' => -6.8, 'last_known_lng' => 39.2, 'last_known_at' => $staleTime,
            'last_known_speed_kmh' => 0,
        ]);
        $job = Job::factory()->create([
            'assigned_truck_id' => $truck->id, 'status' => 'in_transit',
            'gps_tracking_active' => true, 'gps_signal_status' => 'lost',
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, $staleTime->subMinute(), 40.0))->handle(app(JobStatusAutoAdvancer::class));

        $truck->refresh();
        // last_known_speed_kmh would be 40.0 if the telemetry update ran —
        // it must not have, since the position wasn't genuinely fresh.
        $this->assertEqualsWithDelta(0.0, (float) $truck->last_known_speed_kmh, 0.0001);
        $this->assertSame('lost', $job->fresh()->gps_signal_status);
        Event::assertNotDispatched(TruckLocationUpdated::class);
        $this->assertSame(0, JobLocationSnapshot::where('job_id', $job->id)->count());
    }

    /**
     * End-to-end through the real job dispatch entry point (not
     * JobStatusAutoAdvancer directly, see JobStatusAutoAdvancerTest for
     * that): a short-haul job (pickup and drop-off only ~3km apart) must
     * still walk its full real lifecycle — assigned -> en_route_pickup ->
     * picked_up -> in_transit -> the "arrived at destination" notification
     * — driven purely by successive real GPS pings from this job, the same
     * way PollGpsPositionsJob dispatches it in production.
     */
    public function test_a_short_haul_job_reaches_arrival_through_the_full_pipeline(): void
    {
        $pickup = ['lat' => -6.8161, 'lng' => 39.2803];
        // ~3km from pickup.
        $dropoff = ['lat' => -6.84, 'lng' => 39.2803];

        $customer = User::factory()->create();
        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        $job = Job::factory()->create([
            'customer_id' => $customer->id,
            'assigned_truck_id' => $truck->id,
            'status' => 'assigned',
            'pickup_location' => (new GeoPoint($pickup['lat'], $pickup['lng']))->toInsertExpression(),
            'dropoff_location' => (new GeoPoint($dropoff['lat'], $dropoff['lng']))->toInsertExpression(),
        ]);

        $advancer = app(JobStatusAutoAdvancer::class);
        $now = CarbonImmutable::now();

        // Ping 1: any position at all advances 'assigned' -> 'en_route_pickup'.
        (new NormalizeGpsPositionJob($truck->id, -6.9, 39.4, 45.0, $now, 40.0))->handle($advancer);
        $this->assertSame('en_route_pickup', $job->fresh()->status);

        // Ping 2: at the pickup point -> 'picked_up'.
        (new NormalizeGpsPositionJob($truck->id, $pickup['lat'], $pickup['lng'], 45.0, $now->addMinute(), 0.0))->handle($advancer);
        $this->assertSame('picked_up', $job->fresh()->status);

        // Ping 3: ~2km from pickup — short of the flat 5km default radius,
        // but past 40% of this job's own ~3km total distance, so it must
        // already reach 'in_transit' here rather than staying stuck at
        // 'picked_up' for the rest of the trip.
        (new NormalizeGpsPositionJob($truck->id, -6.834, 39.2803, 45.0, $now->addMinutes(2), 40.0))->handle($advancer);
        $this->assertSame('in_transit', $job->fresh()->status);

        // Ping 4: at the drop-off — the customer must actually get told,
        // which only happens once status is 'in_transit'. With the old
        // flat-radius bug this job could never have reached that status at
        // all, so this notification would never have sent.
        (new NormalizeGpsPositionJob($truck->id, $dropoff['lat'], $dropoff['lng'], 45.0, $now->addMinutes(3), 5.0))->handle($advancer);

        $job->refresh();
        $this->assertSame('in_transit', $job->status);
        $this->assertNotNull($job->dropoff_arrival_notified_at);
        $this->assertDatabaseHas('notifications', ['user_id' => $customer->id, 'type' => 'job_arrived_at_dropoff']);
        $this->assertSame(1, Notification::where('type', 'job_arrived_at_dropoff')->count());
    }

    public function test_the_status_advancer_runs_for_a_tier_3_award(): void
    {
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 20]);
        $bid = Bid::factory()->for($job)->create(['trucks_offered' => 8]);
        $award = JobAward::create([
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $bid->transporter_company_id,
            'trucks_offered' => 8,
            'agreed_price' => $bid->price,
        ]);
        $truck = Truck::factory()->approved()->create(['current_status' => 'on_job']);
        JobTruckAssignment::create([
            'job_id' => $job->id,
            'job_award_id' => $award->id,
            'truck_id' => $truck->id,
            'driver_id' => Driver::factory()->create()->id,
            'is_lead' => true,
            'assigned_at' => now(),
        ]);

        (new NormalizeGpsPositionJob($truck->id, -6.8, 39.2, 45.0, CarbonImmutable::now()))->handle(app(JobStatusAutoAdvancer::class));

        $this->assertSame('en_route_pickup', $award->fresh()->status);
        // Never the job's own status — Tier 3 awards advance independently.
        $this->assertSame('open', $job->fresh()->status);
    }
}
