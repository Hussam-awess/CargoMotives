<?php

namespace App\Http\Controllers\Webhooks;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Services\Commission\CommissionLedgerService;
use App\Services\Featured\FeaturedTierService;
use App\Services\MobileMoney\MobileMoneyGateway;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Selcom's payment-outcome callback (TRD §7: "signature-verified and
 * processed idempotently... a spoofed or duplicated webhook has real
 * financial consequences"). Deliberately unauthenticated (no Sanctum
 * guard — Selcom's server has no user session) but never trusted without
 * a valid signature over the raw body.
 *
 * See App\Services\MobileMoney\Selcom\SelcomMobileMoneyGateway's docblock
 * for the same caveat that applies here: the exact payload field names
 * below are a best-effort model of how this class of webhook generally
 * looks, not verified against a live Selcom account.
 */
class SelcomWebhookController extends Controller
{
    public function __construct(
        private readonly MobileMoneyGateway $gateway,
        private readonly CommissionLedgerService $ledger,
        private readonly FeaturedTierService $featuredTier,
    ) {}

    public function handle(Request $request): JsonResponse
    {
        $rawBody = $request->getContent();

        if (! $this->gateway->verifyWebhookSignature($rawBody, $request->header('X-Selcom-Signature'))) {
            Log::warning('Selcom webhook rejected: invalid signature.');

            return response()->json(['message' => 'Invalid signature.'], 401);
        }

        $payload = $request->json()->all();
        $reference = $payload['order_id'] ?? null;
        $paymentStatus = $payload['payment_status'] ?? null;

        $payment = $reference !== null ? Payment::where('gateway_reference', $reference)->first() : null;

        if ($payment === null) {
            // A reference we don't recognize can't be fixed by Selcom
            // retrying — ack it so the retry loop doesn't run forever,
            // but log it since it's still worth a human noticing.
            Log::warning('Selcom webhook for an unknown payment reference.', ['order_id' => $reference]);

            return response()->json(['message' => 'ok']);
        }

        // Idempotency (Business Rule §8 / TRD §7): a retried "succeeded"
        // delivery must never credit the ledger twice, and a late/
        // out-of-order "failed" delivery must never downgrade a payment
        // already confirmed successful.
        //
        // The status check must happen INSIDE the same transaction as the
        // update, against a row-locked read — checking it beforehand (as
        // this used to do) is a TOCTOU race: two genuinely concurrent
        // webhook deliveries for the same reference (Selcom does retry on
        // a slow ack) could both read 'pending_confirmation' before either
        // commits, both pass the guard, and both credit the ledger. A
        // Phase 10 audit caught this — the only prior regression test
        // called the endpoint sequentially, which can never exercise the
        // race, since the second call always sees the already-committed
        // 'succeeded' status by the time it reads.
        DB::transaction(function () use ($payment, $payload, $paymentStatus) {
            $locked = Payment::whereKey($payment->id)->lockForUpdate()->first();

            if ($locked->status === 'succeeded') {
                return;
            }

            if ($paymentStatus === 'COMPLETED') {
                $locked->update(['status' => 'succeeded', 'raw_gateway_payload' => $payload]);

                // What "succeeding" actually does depends on what was being
                // paid for — a commission paydown credits the ledger, a
                // Featured purchase flips is_featured (AppFlow: "unlocks
                // immediately," meaning the instant this webhook lands, not
                // the initiate-purchase response).
                match ($locked->purpose) {
                    'commission_payment' => $this->ledger->applyPayment($locked->fresh()),
                    'featured_company', 'featured_customer' => $this->featuredTier->activateFromPayment($locked->fresh()),
                };
            } elseif ($paymentStatus === 'FAILED' || $paymentStatus === 'CANCELLED') {
                $locked->update(['status' => 'failed', 'raw_gateway_payload' => $payload]);
            }
        });

        return response()->json(['message' => 'ok']);
    }
}
