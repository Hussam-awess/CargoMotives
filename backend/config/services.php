<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Cargo Motives Third-Party Services (TRD §12)
    |--------------------------------------------------------------------------
    */

    // Push notifications (FCM) — key events per AppFlow §6.
    'fcm' => [
        'project_id' => env('FCM_PROJECT_ID'),
        'credentials_path' => env('FCM_CREDENTIALS_PATH'),
    ],

    // Maps — pins, live tracking, geocoding.
    'google_maps' => [
        'api_key' => env('GOOGLE_MAPS_API_KEY'),
    ],

    // Mobile money aggregator — commission + Featured payments (TRD §7).
    // Webhooks are verified against 'webhook_secret' and processed
    // idempotently keyed on the gateway's own transaction reference.
    'selcom' => [
        'api_key' => env('SELCOM_API_KEY'),
        'api_secret' => env('SELCOM_API_SECRET'),
        'vendor_id' => env('SELCOM_VENDOR_ID'),
        'base_url' => env('SELCOM_BASE_URL', 'https://apigwtest.selcommobile.com'),
        'webhook_secret' => env('SELCOM_WEBHOOK_SECRET'),
    ],

    // GPS providers (TRD §5) — concrete per-provider config, not a generic
    // framework. A company picks one of these per GpsConnection; there is
    // no single "default" GPS provider for the whole app the way SMS/push
    // have (see GpsProviderManager).
    'wialon' => [
        'token' => env('WIALON_TOKEN'),
        'base_url' => env('WIALON_BASE_URL', 'https://hst-api.wialon.com'),
    ],

    'traccar' => [
        'base_url' => env('TRACCAR_BASE_URL'),
    ],

    'tracksolid_pro' => [
        'base_url' => env('TRACKSOLID_BASE_URL', 'https://openapi.tracksolid.com'),
    ],

];
