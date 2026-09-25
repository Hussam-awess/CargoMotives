<?php

namespace App\Services\Sms\Drivers;

use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

/**
 * Beem Africa SMS API v1 (https://apisms.beem.africa/v1/send) — the SMS
 * gateway named as the "leading candidate" in the README's vendor table.
 * Live-verified 2026-09-18 once the "CargoMotive" sender ID was approved:
 * real SMS delivered to three real Tanzanian numbers, sender name showing
 * correctly, `successful: true` with a real `request_id` in Beem's own
 * response — the wire shape below (HTTP Basic Auth, `source_addr`/
 * `recipients` JSON body, `successful`/`request_id` in the response) is
 * confirmed correct, not a documentation guess anymore.
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

    /**
     * Beem's plain-text encoding (encoding: 0) rejects the whole message —
     * HTTP 400 API_UNSUPPORTED_VALUE — if it contains any Unicode, and
     * several of this app's messages do: "A → B" routes in notifications,
     * em dashes, and whatever a company types into driver instructions
     * (curly quotes, emoji). Transliterate instead of losing the SMS.
     */
    public static function toPlainText(string $body): string
    {
        $body = strtr($body, [
            "\u{2192}" => '->', "\u{2190}" => '<-', "\u{2014}" => '-', "\u{2013}" => '-',
            "\u{2018}" => "'", "\u{2019}" => "'", "\u{201C}" => '"', "\u{201D}" => '"',
            "\u{2026}" => '...', "\u{2022}" => '*', "\u{00A0}" => ' ',
        ]);

        // Str::ascii transliterates accents (é -> e) — applied per line, as it
        // would otherwise flatten a multi-line driver instruction into one.
        // Anything with no ASCII equivalent (emoji) is dropped rather than
        // failing the send.
        $body = (string) preg_replace_callback('/[^\r\n]+/', fn (array $line) => Str::ascii($line[0]), $body);

        return (string) preg_replace('/[^\x09\x0A\x0D\x20-\x7E]/', '', $body);
    }

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
                    'message' => self::toPlainText($body),
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
