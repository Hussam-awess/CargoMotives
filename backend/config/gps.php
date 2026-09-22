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
    // pickup area, not just circled the same depot lot.
    'job_status_departure_radius_km' => env('GPS_JOB_STATUS_DEPARTURE_RADIUS_KM', 5),

];
