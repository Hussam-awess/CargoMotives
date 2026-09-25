<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cargo Motives Plus Tuning
    |--------------------------------------------------------------------------
    |
    | Infrastructure knobs, not Admin-editable business rules — same
    | reasoning as config/gps.php and config/otp.php. The price/duration
    | themselves live in PlatformSettings (Admin-editable), unlike this file.
    |
    */

    // How many days before featured_until NotifyFeaturedExpiringSoon warns
    // the user/company — long enough to give them a real chance to renew
    // before benefits actually lapse.
    'expiry_reminder_days_before' => env('FEATURED_EXPIRY_REMINDER_DAYS_BEFORE', 3),

];
