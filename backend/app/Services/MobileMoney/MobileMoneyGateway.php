<?php

namespace App\Services\MobileMoney;

/**
 * Contract for the one mobile money aggregator this app integrates (TRD
 * §1: "One licensed aggregator... pick one, don't integrate several in
 * parallel for MVP" — Selcom). Kept thin and concrete-integration-shaped
 * (same reasoning as App\Services\Gps\GpsProvider): the two things this
 * app actually needs are "push a charge to a phone" and "verify a webhook
 * really came from the gateway," so that's the whole interface.
 */
interface MobileMoneyGateway
{
    public function initiateCharge(string $gatewayReference, float $amount, string $provider, string $phoneNumber): MobileMoneyChargeResult;

    /**
     * TRD §7: "Payment... webhooks are signature-verified and processed
     * idempotently... a spoofed or duplicated webhook has real financial
     * consequences." $rawBody must be the exact, unparsed request body —
     * signatures are computed over raw bytes, not a re-serialized array.
     */
    public function verifyWebhookSignature(string $rawBody, ?string $signatureHeader): bool;
}
