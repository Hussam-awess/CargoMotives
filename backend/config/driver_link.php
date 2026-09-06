<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Driver Link Expiry
    |--------------------------------------------------------------------------
    |
    | An infrastructure tuning knob (not an Admin-editable business rule —
    | see config/otp.php's comment for the same reasoning), so it lives here
    | rather than in platform_settings.
    |
    | A Driver Link stays valid for the whole job, not just a single visit:
    | the driver may reopen it across a multi-day haul to post status
    | updates before finally submitting proof of delivery, at which point it
    | is marked "used" regardless of how much of this window remains. The
    | window just needs to comfortably outlast any realistic job duration —
    | it is not a security-sensitive "short OTP-style" expiry.
    |
    */

    'expiry_days' => env('DRIVER_LINK_EXPIRY_DAYS', 14),

];
