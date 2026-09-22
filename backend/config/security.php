<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Login Lockout
    |--------------------------------------------------------------------------
    |
    | Defense in depth alongside the per-route `throttle:*` rate limiters
    | (AppServiceProvider), which key on identifier+IP together and so can
    | be sailed past by an attacker who simply rotates IPs. LoginThrottle
    | keys on the identifier (phone/email) alone, so it still catches a
    | distributed brute-force attempt against one account.
    */

    'login_max_attempts' => 5,

    'login_lockout_minutes' => 15,

];
