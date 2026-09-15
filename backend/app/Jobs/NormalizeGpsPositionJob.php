<?php

namespace App\Jobs;

use App\Events\TruckLocationUpdated;
use App\Models\Job as JobModel;
use App\Models\JobLocationSnapshot;
use App\Models\Truck;
use App\Services\Geo\GeoPoint;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Queue\ShouldQueue;
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
    ) {}

    public function handle(): void
    {
        $truck = Truck::find($this->truckId);
        if ($truck === null) {
            return;
        }

        $recordedAt = $this->recordedAt ?? now();

        // Providers sometimes re-return the same last-known ping on
        // successive polls (nothing new to report) — ignore anything not
        // strictly newer than what's already stored, so a delayed/
        // out-of-order response can never regress last_known_at.
        if ($truck->last_known_at !== null && $recordedAt->lessThanOrEqualTo($truck->last_known_at)) {
            return;
        }

        $truck->update([
            'last_known_lat' => $this->lat,
            'last_known_lng' => $this->lng,
            'last_known_heading' => $this->heading,
            'last_known_speed_kmh' => $this->speedKmh,
            'last_known_at' => $recordedAt,
            // A position arriving at all means the feed is alive — this is
            // also how a truck recovers from 'signal_lost' back to
            // 'connected' without any separate "recovery" logic needed.
            'gps_status' => 'connected',
        ]);

        $job = JobModel::where('assigned_truck_id', $truck->id)
            ->whereIn('status', ['assigned', 'en_route_pickup', 'picked_up', 'in_transit'])
            ->first();

        if ($job === null) {
            // Truck isn't on a trackable job right now (idle, or between
            // jobs) — its last-known position is still updated above for
            // whenever it next is, but there's no job screen to broadcast to.
            return;
        }

        $job->update(['gps_tracking_active' => true, 'gps_signal_status' => 'ok']);

        $this->recordThrottledSnapshot($job, $truck, $recordedAt);

        broadcast(new TruckLocationUpdated($job, $truck));
    }

    private function recordThrottledSnapshot(JobModel $job, Truck $truck, CarbonImmutable $recordedAt): void
    {
        // Deliberately ->first() (through the model, so `recorded_at`
        // comes back cast to Carbon) rather than a raw ->value() —
        // comparing a Carbon instance against a plain DB-driver string
        // silently broke the throttle below in a way this behavior's own
        // test caught.
        $lastSnapshot = $job->locationSnapshots()->latest('recorded_at')->first();
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

        JobLocationSnapshot::record($job->id, $truck->id, new GeoPoint($this->lat, $this->lng), $recordedAt);
    }
}
