<?php

namespace App\Services\Sms\Drivers;

use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Beem Africa SMS API v1 (https://apisms.beem.africa/v1/send) — the SMS
 * gateway named as the "leading candidate" in the README's vendor table.
 * Modeled on Beem's public v1 REST API (HTTP Basic Auth with the API
 * key/secret pair, a JSON body naming the sender ID and a list of
 * recipients), the same "best available public documentation, no live
 * account in this environment to confirm the exact wire shape against"
 * caveat as SelcomMobileMoneyGateway's own docblock — verify the endpoint,
 * field names, and response shape against a real Beem dashboard/API key
 * before this ever carries production OTP or Driver Link traffic.
 *
 * Never throws — every failure mode (network error, malformed response, a
 * provider-reported decline) is caught and returned as
 * SmsSendResult::failure(), matching the same graceful-degradation
 * contract every SmsGateway driver honors (TRD §5.3): OTP and Driver Link
 * delivery both stay usable (a re-sendable code, a link the company can
 * re-share) even when the SMS itself never goes out.
 */
class BeemSmsDriver implements SmsGateway
{
    private const ENDPOINT = 'https://apisms.beem.africa/v1/send';

    public function __construct(
        private readonly string $apiKey,
        private readonly string $secretKey,
        private readonly string $senderId,
    ) {}

    public function send(string $to, string $body): SmsSendResult
    {
        // This app's canonical phone format (PhoneNumberNormalizer) keeps
        // the leading "+" (+255712345678); Beem's API expects the
        // destination without it (255712345678) — exactly the
        // provider-specific formatting SmsGateway::send()'s docblock
        // leaves to each driver.
        $destination = ltrim($to, '+');

        try {
            $response = Http::timeout(15)
                ->withBasicAuth($this->apiKey, $this->secretKey)
                ->acceptJson()
                ->post(self::ENDPOINT, [
                    'source_addr' => $this->senderId,
                    'encoding' => 0,
                    'message' => $body,
                    'recipients' => [
                        ['recipient_id' => 1, 'dest_addr' => $destination],
                    ],
                ]);
        } catch (Throwable $e) {
            Log::warning('Beem SMS send could not reach the gateway', ['error' => $e->getMessage()]);

            return SmsSendResult::failure("Could not reach Beem: {$e->getMessage()}");
        }

        $payload = $response->json();

        if ($response->failed() || ! is_array($payload)) {
            Log::warning('Beem SMS send returned an unexpected response', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            return SmsSendResult::failure("Beem returned an unexpected response (HTTP {$response->status()}).");
        }

        if (($payload['successful'] ?? false) !== true) {
            return SmsSendResult::failure($payload['message'] ?? 'Beem declined the message.');
        }

        return SmsSendResult::success(
            providerMessageId: isset($payload['request_id']) ? (string) $payload['request_id'] : null,
        );
    }
}
