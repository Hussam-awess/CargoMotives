<?php

namespace Tests\Concerns;

use App\Mail\CustomerOtpMail;
use App\Services\Sms\SmsGateway;
use Illuminate\Support\Facades\Mail;
use Tests\Fakes\FakeSmsGateway;

/**
 * OtpService/EmailOtpService keep only a hash of each code in the cache, so
 * tests read the code from where a real user gets it: the SMS (via
 * fakeSms()) or the CustomerOtpMail (via Mail::fake()).
 */
trait CapturesOtpCodes
{
    private ?FakeSmsGateway $fakeSmsGateway = null;

    protected function fakeSms(): FakeSmsGateway
    {
        $this->fakeSmsGateway = new FakeSmsGateway;
        $this->app->instance(SmsGateway::class, $this->fakeSmsGateway);

        return $this->fakeSmsGateway;
    }

    /**
     * The code in the latest SMS to $phone (normalized, e.g. +255712345678).
     */
    protected function smsCodeSentTo(string $phone): string
    {
        $this->assertNotNull($this->fakeSmsGateway, 'Call fakeSms() before the code is sent.');

        $body = collect($this->fakeSmsGateway->sent)->where('to', $phone)->last()['body'] ?? null;
        $this->assertNotNull($body, "No SMS was sent to {$phone}.");

        $this->assertSame(1, preg_match('/\b(\d{'.config('otp.code_length').'})\b/', $body, $matches), "No code in the SMS: {$body}");

        return $matches[1];
    }

    /**
     * The code in the latest CustomerOtpMail to $email. Needs Mail::fake().
     */
    protected function emailCodeSentTo(string $email): string
    {
        $mail = Mail::sent(CustomerOtpMail::class, fn (CustomerOtpMail $mail) => $mail->hasTo($email))->last();
        $this->assertNotNull($mail, "No CustomerOtpMail was sent to {$email}.");

        return $mail->code;
    }

    /**
     * A well-formed code guaranteed not to be $code.
     */
    protected function wrongCodeFor(string $code): string
    {
        return str_pad((string) (((int) $code + 1) % (10 ** strlen($code))), strlen($code), '0', STR_PAD_LEFT);
    }
}
