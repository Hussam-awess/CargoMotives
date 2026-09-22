<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Bidding Deadline Bounds
    |--------------------------------------------------------------------------
    |
    | How soon/far out a customer's chosen bidding deadline may be, counted
    | from the moment they post (or edit) the job — an infrastructure/
    | business tuning knob, same reasoning as config/driver_link.php's
    | expiry_days, not something Admin edits live via platform_settings.
    |
    | Uniform for every job today — no Featured-only override exists yet
    | (Bidding Deadline epic's "Explicitly out of scope"). Loosening this
    | later, if ever needed, is a one-line config change, not a redesign.
    |
    */

    'min_days' => env('BIDDING_DEADLINE_MIN_DAYS', 1),

    'max_days' => env('BIDDING_DEADLINE_MAX_DAYS', 7),

];
