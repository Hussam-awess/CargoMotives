<?php

namespace App\Jobs;

use App\Events\AwardLocationUpdated;
use App\Events\TruckLocationUpdated;
use App\Models\Job as JobModel;
use App\Models\JobLocationSnapshot;
use App\Models\JobTruckAssignment;
use App\Models\Truck;
use App\Services\Geo\GeoPoint;
use App\Services\Jobs\JobStatusAutoAdvancer;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * The "normalizer job" stage of the async GPS pipeline (TRD §5.2):
 * GPS Provider -> poll -> queue -> **normalizer job** -> trucks.last_known_*
 * -> throttled snapshot -> WebSocket broadcast. Deliberately queued
 * separately from PollGpsPositionsJob (which just fetches and dispatches
 * one of these per unit) so a slow burst of positions never blocks the
 * poll cycle itself, and so one bad position can fail/retry independently
 * of the others.
 */
class NormalizeGpsPositionJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, SerializesModels;

    public function __construct(
        public int $truckId,
        public float $lat,
        public float $lng,
        public ?float $heading,
        public ?CarbonImmutable $recordedAt,
        public ?float $speedKmh = null,
        public ?string $driverName = null,
    ) {}

    public function handle(JobStatusAutoAdvancer $statusAdvancer): void
    {
        $truck = Truck::find($this->truckId);
        if ($truck === null) {
            return;
        }

        $recordedAt = $this->recordedAt ?? now();

        // Providers sometimes re-return the same last-known ping on
        // successive polls (nothing new to report — common for a tracker
        // that only refreshes its fix on movement/ignition, so a parked
        // truck can hold the exact same reading for a long time). Ignore
        // anything not strictly newer than what's already stored for the
        // *display/telemetry* fields below, so a delayed/out-of-order
        // response can never regress last_known_at. This must NOT also
        // gate status auto-advancement further down — see there for why.
        $isFreshPosition = $truck->last_known_at === null
            || $recordedAt->greaterThan($truck->last_known_at);

        if ($isFreshPosition) {
            // Slow now, but wasn't a moment ago -> start the stationary
            // clock. No longer slow -> the truck moved again, clear it.
            // Already slow -> leave the original timestamp alone so
            // Truck::isMoving() can tell how long it's been stationary,
            // not just that it currently is.
            $threshold = (float) config('gps.stationary_speed_threshold_kmh', 3);
            $isSlow = $this->speedKmh !== null && $this->speedKmh < $threshold;
            $stationarySince = $isSlow ? ($truck->stationary_since ?? $recordedAt) : null;

            // gps_driver_name is the DISPLAYED value; gps_raw_driver_name
            // only ever tracks the last raw value actually seen from the
            // provider. Only adopt the incoming value when the provider's
            // own raw value has genuinely changed since last time — a
            // real, confirmed case: a device is simply mislabeled at the
            // source (e.g. Tracksolid itself still says "SULE" for a
            // truck whose real driver is "Paulo"), and unconditionally
            // overwriting on every single poll meant a manual correction
            // for that never survived past the next minute. When the
            // provider's raw value does change, that's a genuine update
            // and should win immediately (self-healing).
            $driverNameFields = $this->driverName === $truck->gps_raw_driver_name
                ? []
                : ['gps_driver_name' => $this->driverName, 'gps_raw_driver_name' => $this->driverName];

            $truck->update([
                'last_known_lat' => $this->lat,
                'last_known_lng' => $this->lng,
                'last_known_heading' => $this->heading,
                'last_known_speed_kmh' => $this->speedKmh,
                'stationary_since' => $stationarySince,
                'last_known_at' => $recordedAt,
                // A position arriving at all means the feed is alive —
                // this is also how a truck recovers from 'signal_lost'
                // back to 'connected' without any separate "recovery"
                // logic needed.
                'gps_status' => 'connected',
                ...$driverNameFields,
            ]);
        }

        $job = JobModel::withCoordinates()
            ->where('assigned_truck_id', $truck->id)
            ->whereIn('status', ['assigned', 'en_route_pickup', 'picked_up', 'in_transit'])
            ->first();

        if ($job !== null) {
            // gps_signal_status recovery (lost -> ok) deliberately stays
            // gated on a genuinely fresh position — CheckGpsSignalLoss's
            // own docblock documents that as the only way back to 'ok'.
            if ($isFreshPosition) {
                $job->update(['gps_tracking_active' => true, 'gps_signal_status' => 'ok']);
            }

            // Status auto-advancement runs on every poll response,
            // fresh or not: JobStatusAutoAdvancer::advance()'s own
            // docblock says "the mere presence of a fresh GPS ping...
            // means it's now genuinely en route" — a device that holds
            // the exact same reading while parked (this is normal
            // tracker behavior, not a fault) must not permanently block
            // that first "assigned -> en_route_pickup" transition, or a
            // proximity threshold, from ever being evaluated at all.
            // Idempotent either way (re-checking an unchanged position
            // against a threshold, or a status the job already left,
            // does nothing), so there's no cost to running it here
            // unconditionally.
            $statusAdvancer->advance($job, $job, new GeoPoint($this->lat, $this->lng));

            if ($isFreshPosition) {
                $this->recordThrottledSnapshot($job->id, null, $job->locationSnapshots(), $truck, $recordedAt);

                broadcast(new TruckLocationUpdated($job, $truck));
            }

            return;
        }

        // Multi-Company Split Awards epic: a job with 2+ awards never sets
        // assigned_truck_id (there's no single "the" company), so the
        // lookup above finds nothing for one of its awards' lead trucks —
        // without this fallback, that award's live map would silently
        // never update, with no error anywhere.
        $assignment = JobTruckAssignment::where('truck_id', $truck->id)
            ->where('is_lead', true)
            ->whereNotNull('job_award_id')
            ->with(['jobAward.job' => fn ($query) => $query->withCoordinates()])
            ->first();

        $award = $assignment?->jobAward;
        if ($award === null || ! $award->isGpsTrackable()) {
            // Truck isn't on a trackable job or award right now (idle, or
            // between jobs) — its last-known position is still updated
            // above for whenever it next is, but there's nothing to
            // broadcast to.
            return;
        }

        // Same split as the Tier 1/2 branch above: signal recovery stays
        // gated on a genuinely fresh position, status advancement doesn't.
        if ($isFreshPosition) {
            $award->update(['gps_tracking_active' => true, 'gps_signal_status' => 'ok']);
        }

        $statusAdvancer->advance($award, $award->job, new GeoPoint($this->lat, $this->lng));

        if ($isFreshPosition) {
            $this->recordThrottledSnapshot($award->job_id, $award->id, $award->locationSnapshots(), $truck, $recordedAt);

            broadcast(new AwardLocationUpdated($award, $truck));
        }
    }

    /**
     * @param  HasMany<JobLocationSnapshot, *>  $snapshots
     */
    private function recordThrottledSnapshot(int $jobId, ?int $jobAwardId, $snapshots, Truck $truck, CarbonImmutable $recordedAt): void
    {
        // Deliberately ->first() (through the model, so `recorded_at`
        // comes back cast to Carbon) rather than a raw ->value() —
        // comparing a Carbon instance against a plain DB-driver string
        // silently broke the throttle below in a way this behavior's own
        // test caught.
        $lastSnapshot = $snapshots->latest('recorded_at')->first();
        $throttleMinutes = (int) config('gps.snapshot_throttle_minutes', 5);

        // abs() is load-bearing, not defensive: Carbon 3 changed diffInX()
        // to return a *signed* difference by default (unlike Carbon 2's
        // always-positive default) — ($recordedAt is always the newer
        // timestamp here, so the raw diff comes back negative, which made
        // `< $throttleMinutes` true unconditionally and permanently
        // disabled this throttle after the very first snapshot. Caught by
        // this behavior's own test, not by inspection — a good reminder to
        // never trust a diffInX() sign without checking it.
        if ($lastSnapshot !== null && abs($recordedAt->diffInMinutes($lastSnapshot->recorded_at)) < $throttleMinutes) {
            return;
        }

        JobLocationSnapshot::record($jobId, $truck->id, new GeoPoint($this->lat, $this->lng), $recordedAt, $jobAwardId);
    }
}
