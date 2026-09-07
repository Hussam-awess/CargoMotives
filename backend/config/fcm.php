<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Push Driver
    |--------------------------------------------------------------------------
    |
    | Push notifications are Firebase Cloud Messaging (TRD §1/§12), used for
    | the nine events in AppFlow §6's Notification Trigger Map (everything
    | except the Driver Link, which stays SMS, and Admin's dispute flag,
    | which stays an in-app dashboard note).
    |
    | The "log" driver writes the push to the application log instead of
    | sending it — same graceful-degradation pattern as SMS_DRIVER=log
    | (config/sms.php). It lets the whole notification pipeline (creation,
    | in-app list, read state, badge count) be built and tested end to end
    | without a real Firebase project; only actual device delivery needs
    | one. Switch to "firebase" once FCM_PROJECT_ID/FCM_CREDENTIALS_PATH
    | below point at a real project.
    |
    | Supported: "log", "firebase"
    |
    */

    'default' => env('PUSH_DRIVER', 'log'),

    'project_id' => env('FCM_PROJECT_ID'),

    // Path to the Firebase service-account JSON key (Firebase Console →
    // Project Settings → Service Accounts → Generate new private key).
    // Never commit this file — keep it outside the repo (or gitignored)
    // and point this at its real path.
    'credentials_path' => env('FCM_CREDENTIALS_PATH'),

];
