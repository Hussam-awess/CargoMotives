<?php

namespace App\Services\MobileMoney\Selcom;

use App\Services\MobileMoney\MobileMoneyChargeResult;
use App\Services\MobileMoney\MobileMoneyGateway;
use App\Services\MobileMoney\MobileMoneyGatewayException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Throwable;

/**
 * Selcom (TRD §1's chosen mobile money aggregator) integration — a
 * "USSD push" charge: the customer/company gets a prompt on their own
 * phone to approve, confirmed later by Selcom's webhook, never assumed
 * synchronously from the initiate call's response.
 *
 * IMPORTANT — unlike WialonGpsProvider (whose request/response shape is
 * well-established public API documentation this integration follows
 * closely), this class models Selcom's signed-header checkout pattern as
 * best can be determined without a live merchant account or current API
 * reference in hand: a base64 `Authorization` header carrying the API key
 * plus an HMAC-SHA256 signature over a canonical, sorted field=value
 * string, computed with the merchant's API secret. The *shape* of this
 * approach (signed fields, an idempotent order/reference id, an
 * asynchronous webhook confirming the actual payment outcome) reflects
 * how Tanzanian mobile money gateways generally work and is what the
 * domain logic around it (Payment, idempotency, graceful degradation) is
 * built and tested against — but the *exact*
 * endpoint path, field names, and header names here should be confirmed
 * against Selcom's current merchant API documentation before this is
 * ever pointed at a real account. No sandbox credentials exist in this
 * environment to verify the wire format against (SELCOM_* env vars are
 * unset) — the same honest constraint WialonGpsProvider hit with
 * WIALON_TOKEN, just for a payment gateway instead of a GPS one.
 */
class SelcomMobileMoneyGateway implements MobileMoneyGateway
{
    public function __construct(
        private readonly string $baseUrl,
        private readonly string $apiKey,
        private readonly string $apiSecret,
        private readonly string $vendorId,
        private readonly string $webhookSecret,
    ) {}

    public function initiateCharge(string $gatewayReference, float $amount, string $provider, string $phoneNumber): MobileMoneyChargeResult
    {
        $fields = [
            'vendor' => $this->vendorId,
            'order_id' => $gatewayReference,
            'buyer_phone' => $phoneNumber,
            'amount' => number_format($amount, 2, '.', ''),
            'currency' => 'TZS',
            'payment_method' => $provider,
        ];

        try {
            $response = Http::timeout(15)
                ->withHeaders($this->signedHeaders($fields))
                ->post("{$this->baseUrl}/v1/checkout/create-order-minimal", $fields);
        } catch (Throwable $e) {
            throw new MobileMoneyGatewayException("Could not reach Selcom: {$e->getMessage()}", previous: $e);
        }

        $body = $response->json();

        if ($response->failed() || ! is_array($body)) {
            return MobileMoneyChargeResult::failed(
                "Selcom returned an unexpected response (HTTP {$response->status()}).",
                is_array($body) ? $body : null,
            );
        }

        if (($body['result'] ?? null) !== 'SUCCESS') {
            return MobileMoneyChargeResult::failed($body['message'] ?? 'Selcom declined the charge request.', $body);
        }

        return MobileMoneyChargeResult::initiated($body['reference'] ?? $body['transid'] ?? null, $body);
    }

    public function verifyWebhookSignature(string $rawBody, ?string $signatureHeader): bool
    {
        if ($signatureHeader === null || $signatureHeader === '') {
            return false;
        }

        $expected = hash_hmac('sha256', $rawBody, $this->webhookSecret);

        return hash_equals($expected, $signatureHeader);
    }

    /**
     * @param  array<string, string>  $fields
     * @return array<string, string>
     */
    private function signedHeaders(array $fields): array
    {
        ksort($fields);
        $canonical = collect($fields)->map(fn ($value, $key) => "{$key}={$value}")->implode('&');
        $digest = hash_hmac('sha256', $canonical, $this->apiSecret);
        $authorization = base64_encode("{$this->apiKey}:{$digest}");

        return [
            'Authorization' => "SELCOM {$authorization}",
            'Digest-Method' => 'HS256',
            'Timestamp' => now()->toIso8601String(),
            'Signed-Fields' => implode(',', array_keys($fields)),
            'X-Request-Id' => (string) Str::uuid(),
        ];
    }
}
