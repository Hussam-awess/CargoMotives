<?php

namespace App\Services\Push;

use App\Services\Push\Drivers\FirebasePushDriver;
use App\Services\Push\Drivers\LogPushDriver;
use Illuminate\Support\Manager;

/**
 * Resolves the configured push driver (config('fcm.default')) — the same
 * Manager pattern SmsManager already uses for SMS drivers.
 */
class PushManager extends Manager
{
    public function getDefaultDriver(): string
    {
        return $this->config->get('fcm.default', 'log');
    }

    protected function createLogDriver(): LogPushDriver
    {
        return new LogPushDriver;
    }

    protected function createFirebaseDriver(): FirebasePushDriver
    {
        return new FirebasePushDriver;
    }
}
