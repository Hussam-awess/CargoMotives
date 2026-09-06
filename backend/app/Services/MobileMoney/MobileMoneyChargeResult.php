<?php

namespace App\Services\MobileMoney;

/**
 * Outcome of *initiating* a charge — not the payment itself. A mobile
 * money push (TRD §5.3's graceful-degradation principle applies to
 * payments too: "a commission charge that fails or times out leaves the
 * balance as owed and retryable, it doesn't block the job from
 * completing") only tells you whether the USSD prompt was sent; whether
 * the customer actually approved it is confirmed later, asynchronously,
 * by the gateway's webhook — never assumed from this result alone.
 */
final readonly class MobileMoneyChargeResult
{
    private function __construct(
        public bool $initiated,
        public ?string $providerReference,
        public ?array $rawPayload,
        public ?string $error,
    ) {}

    public static function initiated(?string $providerReference, ?array $rawPayload = null): self
    {
        return new self(initiated: true, providerReference: $providerReference, rawPayload: $rawPayload, error: null);
    }

    public static function failed(string $error, ?array $rawPayload = null): self
    {
        return new self(initiated: false, providerReference: null, rawPayload: $rawPayload, error: $error);
    }
}
