<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

/**
 * Customer registration's email OTP (see EmailOtpService). Not queued
 * (ShouldQueue) — matching OtpService's own synchronous SmsGateway::send()
 * call, since a signup flow needs the send attempt to happen before the
 * response, not sometime later off a queue worker.
 */
class CustomerOtpMail extends Mailable
{
    use SerializesModels;

    public function __construct(public readonly string $code) {}

    public function build(): self
    {
        return $this->subject('Your Cargo Motives verification code')
            ->view('emails.customer-otp')
            ->with([
                'code' => $this->code,
                'ttlMinutes' => (int) (config('otp.ttl_seconds') / 60),
            ]);
    }
}
