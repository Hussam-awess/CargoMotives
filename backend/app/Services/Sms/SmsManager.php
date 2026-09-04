<?php

namespace App\Services\Sms;

use App\Services\Sms\Drivers\LogSmsDriver;
use Illuminate\Support\Manager;
use RuntimeException;

/**
 * Resolves the configured SMS driver (config('sms.default')), the same
 * "Manager" pattern Laravel itself uses for cache/queue/filesystem drivers.
 *
 * Only the "log" driver is implemented today — a deliberate choice (see the
 * plan's Phase 0/1 notes): SMS_DRIVER stays "log" until a real Tanzanian SMS
 * provider is picked, rather than building a half-finished integration
 * against a provider that might not be the final choice.
 */
class SmsManager extends Manager
{
    public function getDefaultDriver(): string
    {
        return $this->config->get('sms.default', 'log');
    }

    protected function createLogDriver(): LogSmsDriver
    {
        return new LogSmsDriver;
    }

    protected function createBeemDriver(): never
    {
        throw new RuntimeException(
            'The "beem" SMS driver is not implemented yet. Set SMS_DRIVER=log for local dev, '
            .'or implement App\\Services\\Sms\\Drivers\\BeemSmsDriver once Beem Africa credentials are available.'
        );
    }

    protected function createAfricastalkingDriver(): never
    {
        throw new RuntimeException(
            'The "africastalking" SMS driver is not implemented yet. Set SMS_DRIVER=log for local dev, '
            .'or implement App\\Services\\Sms\\Drivers\\AfricasTalkingSmsDriver once credentials are available.'
        );
    }
}
