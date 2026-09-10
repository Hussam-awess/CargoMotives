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
 * SMS_DRIVER stays "log" for local dev/CI (no per-message cost, no live
 * account needed) until BEEM_API_KEY/BEEM_SECRET_KEY are actually set —
 * see BeemSmsDriver's own docblock for what "real" means here (Beem Africa,
 * the README's chosen SMS gateway, for OTP + Driver Link delivery).
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
