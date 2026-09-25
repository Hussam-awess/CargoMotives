<?php

return [

    /*
    |--------------------------------------------------------------------------
    | GPS Pipeline Tuning
    |--------------------------------------------------------------------------
    |
    | Infrastructure knobs, not Admin-editable business rules — same
    | reasoning as config/otp.php and config/driver_link.php.
    |
    */

    // How long a GPS-tracked job's truck may go without a fresh position
    // before the job's gps_signal_status flips from 'ok' to 'lost'
    // (TRD §5.3's "GPS signal unavailable" state). The scheduled poll runs
    // roughly every minute, so this should comfortably exceed one missed
    // cycle before declaring the signal lost.
    'signal_lost_after_minutes' => env('GPS_SIGNAL_LOST_AFTER_MINUTES', 10),

    // job_location_snapshots is a throttled route-replay log, not a
    // per-ping history (TRD §5.2) — at most one snapshot per job per this
    // many minutes.
    'snapshot_throttle_minutes' => env('GPS_SNAPSHOT_THROTTLE_MINUTES', 5),

    // Below this instantaneous speed, a fresh ping counts as "slow" for the
    // fleet map's moving/stationary marker color — a few km/h of GPS jitter
    // on a truly parked truck is normal and shouldn't register as movement.
    'stationary_speed_threshold_kmh' => env('GPS_STATIONARY_SPEED_THRESHOLD_KMH', 3),

    // How long a truck must stay continuously "slow" (see above) before the
    // fleet map marks it stationary (red) rather than moving (green) —
    // matches the 15-minute threshold requested for the fleet map.
    'stationary_after_minutes' => env('GPS_STATIONARY_AFTER_MINUTES', 15),

    // Within this straight-line distance of a job's pickup/dropoff point,
    // a fresh position counts as "arrived" for JobStatusAutoAdvancer — a
    // few hundred meters of GPS jitter plus a real depot/warehouse
    // footprint, not a literal doorstep.
    'job_status_arrival_radius_km' => env('GPS_JOB_STATUS_ARRIVAL_RADIUS_KM', 0.5),

    // Beyond this distance from the pickup point, a picked-up job
    // auto-advances to 'in_transit' — the truck has genuinely left the
    // pickup area, not just circled the same depot lot. This is a ceiling,
    // not a fixed distance — see job_status_departure_radius_fraction for
    // why a short-haul job uses a smaller threshold than this.
    'job_status_departure_radius_km' => env('GPS_JOB_STATUS_DEPARTURE_RADIUS_KM', 5),

    // For a job whose pickup and drop-off are close together, the flat
    // radius above can exceed the job's own total distance — the truck
    // would then reach (or pass) the drop-off while still short of that
    // radius, so it would sit at 'picked_up' for the whole trip and the
    // "arrived at destination" notification (which only fires once status
    // is 'in_transit') would never send. JobStatusAutoAdvancer instead
    // uses whichever is smaller: the flat radius above, or this fraction
    // of the job's straight-line pickup-to-dropoff distance — always
    // floored at job_status_arrival_radius_km so it can never sit below
    // (or collide with) the "just arrived at pickup" radius itself.
    'job_status_departure_radius_fraction' => env('GPS_JOB_STATUS_DEPARTURE_RADIUS_FRACTION', 0.4),

    // Beyond this point of approach to the drop-off, JobStatusAutoAdvancer
    // reminds the customer to generate the drop-off permit — comfortably
    // farther out than job_status_arrival_radius_km (0.5km default) so the
    // reminder fires before the "arrived" notification, giving the
    // customer time to prepare the document before the truck actually
    // gets there.
    'dropoff_permit_reminder_radius_km' => env('GPS_DROPOFF_PERMIT_REMINDER_RADIUS_KM', 2.0),

    // How long a job may sit 'in_transit' with GPS-confirmed arrival
    // (dropoff_arrival_notified_at) and the drop-off permit already
    // attached before AutoCompleteStuckDeliveries steps in on its own —
    // long enough that a transporter who's simply slow to tap "End Job"
    // still has a real window to do it themselves first.
    'auto_complete_grace_period_hours' => env('GPS_AUTO_COMPLETE_GRACE_PERIOD_HOURS', 3),

];
