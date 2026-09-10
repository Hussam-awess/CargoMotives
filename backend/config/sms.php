<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default SMS Driver
    |--------------------------------------------------------------------------
    |
    | SMS is used for exactly two things in Cargo Motives: OTP delivery and
    | the Driver Link (TRD §1 — "kept to essentials to control cost"). Per the
    | TRD's graceful-degradation principle, a failure here must never block
    | the underlying flow: OTP falls back to a re-sendable code, and a Driver
    | Link can always be re-shared manually from the company's app.
    |
    | The "log" driver writes the message to the application log instead of
    | sending it, so local dev and CI never depend on a live SMS account or
    | incur real cost. "beem" is a real, implemented driver
    | (App\Services\Sms\Drivers\BeemSmsDriver) — set SMS_DRIVER=beem and the
    | BEEM_* env vars below once a real Beem Africa account exists.
    | "africastalking" has no driver class yet (SmsManager throws if
    | selected).
    |
    | Supported: "log", "beem", "africastalking"
    |
    */

    'default' => env('SMS_DRIVER', 'log'),

    'sender_id' => env('SMS_SENDER_ID', 'CargoMotives'),

    'drivers' => [

        'beem' => [
            'api_key' => env('BEEM_API_KEY'),
            'secret_key' => env('BEEM_SECRET_KEY'),
        ],

        'africastalking' => [
            'username' => env('AFRICASTALKING_USERNAME'),
            'api_key' => env('AFRICASTALKING_API_KEY'),
        ],

    ],

];
