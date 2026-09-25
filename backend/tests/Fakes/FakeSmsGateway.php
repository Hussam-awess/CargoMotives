<?php

namespace Tests\Fakes;

use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;

/**
 * Records every SMS instead of sending it, so a test can read back what a
 * user would actually have received (e.g. an OTP code — the cache only
 * holds its hash). Bound via Tests\Concerns\CapturesOtpCodes::fakeSms().
 */
final class FakeSmsGateway implements SmsGateway
{
    /** @var list<array{to: string, body: string}> */
    public array $sent = [];

    public function send(string $to, string $body): SmsSendResult
    {
        $this->sent[] = ['to' => $to, 'body' => $body];

        return SmsSendResult::success(providerMessageId: 'fake-'.count($this->sent));
    }
}
