<?php

namespace App\Services\Sms\Drivers;

use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;
use Illuminate\Support\Facades\Log;

/**
 * Local-dev / CI stand-in: writes the message to the log instead of sending
 * it. This is what SMS_DRIVER=log (the default until a real provider is
 * chosen) resolves to — it lets OTP and Driver Link flows be built and
 * tested end-to-end without a live SMS account or any per-message cost.
 *
 * To find an OTP code while testing locally: tail storage/logs/laravel.log
 * (or `php artisan pail`) and look for the "SMS (log driver)" entry.
 */
class LogSmsDriver implements SmsGateway
{
    public function send(string $to, string $body): SmsSendResult
    {
        Log::info('SMS (log driver)', [
            'to' => $to,
            'body' => $body,
        ]);

        return SmsSendResult::success(providerMessageId: 'log-'.uniqid());
    }
}
