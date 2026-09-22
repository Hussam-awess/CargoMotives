<?php

namespace App\Services\Jobs;

use App\Models\Job;
use App\Services\Geo\GeoPoint;
use App\Services\Notifications\NotificationService;
use Illuminate\Database\Eloquent\Model;

/**
 * Drives a job's status off the truck's own GPS position instead of the
 * driver manually tapping through the Driver Link page (AppFlow request:
 * "instead of the driver to update manually"). The driver's existing
 * buttons stay as a fallback — DriverLinkPageController::updateStatus()'s
 * own "already moved past that point" guard already rejects a stale
 * manual tap regardless of whether GPS or the driver got there first, so
 * nothing there needed to change.
 *
 * $statusHolder is either the Job itself (Tier 1/2, a single company
 * covers the whole job) or a JobAward (Tier 3 — see the Multi-Company
 * Split Awards epic). Both share the identical status vocabulary and an
 * update() method — the same ($award ?? $job) duck-typing
 * DriverLinkPageController already relies on.
 *
 * Deliberately never advances to 'delivered': that stays a real, manually
 * submitted proof-of-delivery step (photo + recipient name) regardless of
 * GPS position — arriving at the drop-off only sends a notification here,
 * it never mutates status.
 *
 * Customer notifications for the three statuses this DOES set
 * (en_route_pickup/picked_up/in_transit) are sent by JobObserver /
 * JobAwardObserver reacting to wasChanged('status') — not from here — so
 * a manual driver-tap advance notifies the customer identically to an
 * automatic one, with "who changed it" fully decoupled from "does the
 * customer get told."
 */
class JobStatusAutoAdvancer
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function advance(Model $statusHolder, Job $job, GeoPoint $truckPosition): void
    {
        $pickup = new GeoPoint((float) $job->pickup_lat, (float) $job->pickup_lng);
        $dropoff = new GeoPoint((float) $job->dropoff_lat, (float) $job->dropoff_lng);

        match ($statusHolder->status) {
            // No distance check — the mere presence of a fresh GPS ping
            // for an assigned truck means it's now genuinely en route.
            'assigned' => $statusHolder->update(['status' => 'en_route_pickup']),
            'en_route_pickup' => $this->maybeAdvanceToPickedUp($statusHolder, $pickup, $truckPosition),
            'picked_up' => $this->maybeAdvanceToInTransit($statusHolder, $pickup, $truckPosition),
            'in_transit' => $this->maybeNotifyArrivedAtDropoff($statusHolder, $job, $dropoff, $truckPosition),
            default => null,
        };
    }

    private function maybeAdvanceToPickedUp(Model $statusHolder, GeoPoint $pickup, GeoPoint $truckPosition): void
    {
        if ($pickup->kmTo($truckPosition) <= (float) config('gps.job_status_arrival_radius_km', 0.5)) {
            $statusHolder->update(['status' => 'picked_up']);
        }
    }

    private function maybeAdvanceToInTransit(Model $statusHolder, GeoPoint $pickup, GeoPoint $truckPosition): void
    {
        if ($pickup->kmTo($truckPosition) >= (float) config('gps.job_status_departure_radius_km', 5)) {
            $statusHolder->update(['status' => 'in_transit']);
        }
    }

    /**
     * No status change here (see class docblock) — dropoff_arrival_notified_at
     * is the only guard, so this fires exactly once per job/award rather
     * than on every subsequent ping while the truck sits at the drop-off.
     */
    private function maybeNotifyArrivedAtDropoff(Model $statusHolder, Job $job, GeoPoint $dropoff, GeoPoint $truckPosition): void
    {
        if ($statusHolder->dropoff_arrival_notified_at !== null) {
            return;
        }

        if ($dropoff->kmTo($truckPosition) > (float) config('gps.job_status_arrival_radius_km', 0.5)) {
            return;
        }

        // forceFill()->saveQuietly(), not update(): a pure internal guard
        // stamp, not a real state change worth firing model events over —
        // same convention as Job::bidding_expiry_notified_at.
        $statusHolder->forceFill(['dropoff_arrival_notified_at' => now()])->saveQuietly();

        $this->notifications->send(
            $job->customer,
            'job_arrived_at_dropoff',
            'Arrived at destination',
            "Job #{$job->id}'s cargo has arrived at its destination. Awaiting proof of delivery.",
            $job,
        );
    }
}
