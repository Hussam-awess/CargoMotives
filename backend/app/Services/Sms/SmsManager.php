<?php

namespace App\Services\Sms;

use App\Services\Sms\Drivers\BeemSmsDriver;
use App\Services\Sms\Drivers\LogSmsDriver;
use Illuminate\Support\Manager;
use RuntimeException;

/**
 * Resolves the configured SMS driver (config('sms.default')), the same
 * "Manager" pattern Laravel itself uses for cache/queue/filesystem drivers.
 *
 * SMS_DRIVER is "beem" in production now (live-verified 2026-09-18 — see
 * BeemSmsDriver's own docblock) and stays "log" for local dev/CI (no
 * per-message cost, no live account needed) unless BEEM_API_KEY/
 * BEEM_SECRET_KEY/SMS_SENDER_ID are deliberately set there too.
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

    protected function createBeemDriver(): BeemSmsDriver
    {
        $config = $this->config->get('sms.drivers.beem', []);

        if (blank($config['api_key'] ?? null) || blank($config['secret_key'] ?? null)) {
            throw new RuntimeException(
                'SMS_DRIVER=beem but BEEM_API_KEY/BEEM_SECRET_KEY are not set — see backend/.env.example.'
            );
        }

        return new BeemSmsDriver(
            apiKey: $config['api_key'],
            secretKey: $config['secret_key'],
            senderId: $this->config->get('sms.sender_id', 'CargoMotives'),
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
