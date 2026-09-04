<?php

namespace App\Services\Sms;

/**
 * Contract every SMS driver (log, Beem, Africa's Talking, ...) implements.
 *
 * SMS is used for exactly two things in Cargo Motives (TRD §1): OTP codes
 * and the Driver Link. Both call sites depend only on this interface, so
 * swapping the concrete provider later (config/sms.php `default`) never
 * touches call sites — only a new Drivers\* class + a case in SmsManager.
 */
interface SmsGateway
{
    /**
     * Send a single SMS message.
     *
     * @param  string  $to  E.164-ish phone number (provider-specific formatting is the driver's job).
     * @param  string  $body  Plain-text message body.
     */
    public function send(string $to, string $body): SmsSendResult;
}
