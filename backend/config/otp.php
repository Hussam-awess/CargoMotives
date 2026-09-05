<?php

return [

    /*
    |--------------------------------------------------------------------------
    | OTP Mechanics
    |--------------------------------------------------------------------------
    |
    | These are infrastructure tuning knobs (not business rules an Admin
    | should change at runtime — unlike commission rate or bid quotas, which
    | live in platform_settings), so a config file is the right place, not
    | a database table.
    */

    'code_length' => 6,

    // How long a generated code stays valid.
    'ttl_seconds' => 300,

    // Minimum time between two OTP requests for the same phone number —
    // the main lever for keeping the SMS bill predictable (TRD §1).
    'resend_cooldown_seconds' => 60,

    // Wrong guesses allowed before the code is invalidated outright,
    // forcing a fresh request. Blunts brute-forcing a 6-digit code within
    // its TTL window even if rate limiting is somehow bypassed.
    'max_attempts' => 5,

];
