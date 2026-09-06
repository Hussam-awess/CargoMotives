<?php

namespace App\Services\MobileMoney;

use App\Models\Payment;
use Illuminate\Support\Str;

/**
 * Creates a Payment row and pushes the actual mobile money charge —
 * extracted from Phase 7's CommissionController once Phase 8 needed the
 * exact same "create a Payment, call the gateway, record the outcome"
 * sequence for a second purpose (featured_company/featured_customer).
 * Confirmation is always asynchronous (SelcomWebhookController) — this
 * only ever returns 'pending_confirmation' or 'failed', never 'succeeded'.
 */
class MobileMoneyPaymentInitiator
{
    public function __construct(private readonly MobileMoneyGateway $gateway) {}

    public function initiate(int $userId, string $purpose, float $amount, string $provider, string $phoneNumber): Payment
    {
        $payment = Payment::create([
            'user_id' => $userId,
            'purpose' => $purpose,
            'amount' => $amount,
            'mobile_money_provider' => $provider,
            'gateway_reference' => (string) Str::uuid(),
        ]);

        try {
            $result = $this->gateway->initiateCharge($payment->gateway_reference, $amount, $provider, $phoneNumber);
        } catch (MobileMoneyGatewayException $e) {
            $payment->update(['status' => 'failed', 'raw_gateway_payload' => ['error' => $e->getMessage()]]);

            return $payment;
        }

        $payment->update([
            'status' => $result->initiated ? 'pending_confirmation' : 'failed',
            'raw_gateway_payload' => $result->rawPayload,
        ]);

        return $payment;
    }
}
