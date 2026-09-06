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

];
