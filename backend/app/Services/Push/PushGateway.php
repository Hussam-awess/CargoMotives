<?php

namespace App\Services\Push;

/**
 * Contract every push driver (log, firebase, ...) implements. Mirrors
 * App\Services\Sms\SmsGateway's shape exactly — one interface, swappable
 * via config('fcm.default'), so call sites never depend on a concrete
 * driver.
 */
interface PushGateway
{
    /**
     * Send one notification to every given device token for a single user.
     *
     * @param  string[]  $tokens
     * @param  array<string, string>  $data  Extra key/value payload for deep-linking (e.g. related_job_id).
     */
    public function send(array $tokens, string $title, string $body, array $data = []): PushSendResult;
}
