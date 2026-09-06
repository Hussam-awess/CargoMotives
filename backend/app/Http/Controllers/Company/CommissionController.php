<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\InitiateCommissionPaymentRequest;
use App\Http\Resources\CommissionLedgerEntryResource;
use App\Http\Resources\PaymentResource;
use App\Models\Payment;
use App\Services\MobileMoney\MobileMoneyGateway;
use App\Services\MobileMoney\MobileMoneyGatewayException;
use App\Services\Settings\PlatformSettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Str;

/**
 * A company's commission balance, its transaction history, and paying it
 * down via mobile money (AppFlow §2.6/§2.7: "balance display, Commission
 * Due breakdown... Pay via Mobile Money button... Earnings ledger view").
 * The actual balance/ledger writes never happen here — see
 * App\Services\Commission\CommissionLedgerService (the charge side, fired
 * from JobController::confirmDelivery) and SelcomWebhookController (the
 * payment side, fired only once Selcom confirms the charge succeeded).
 */
class CommissionController extends Controller
{
    public function __construct(
        private readonly MobileMoneyGateway $gateway,
        private readonly PlatformSettings $settings,
    ) {}

    public function summary(Request $request): JsonResponse
    {
        $company = $request->user()->transporterCompany;

        return response()->json([
            'outstanding_balance' => (float) $company->outstanding_balance,
            'commission_standing' => $company->commission_standing,
            'hold_threshold' => $this->settings->getFloat('commission_hold_threshold', 500000),
        ]);
    }

    public function ledger(Request $request): AnonymousResourceCollection
    {
        $entries = $request->user()->transporterCompany
            ->commissionLedgerEntries()
            ->latest('id')
            ->paginate(20);

        return CommissionLedgerEntryResource::collection($entries);
    }

    /**
     * Pushes a mobile money charge to the company's own phone. The
     * returned Payment reflects only whether the *push* went out —
     * 'pending_confirmation' means "check your phone," never "paid."
     * Confirmation is asynchronous (SelcomWebhookController); nothing here
     * touches outstanding_balance.
     */
    public function initiatePayment(InitiateCommissionPaymentRequest $request): PaymentResource
    {
        $payment = Payment::create([
            'user_id' => $request->user()->id,
            'purpose' => 'commission_payment',
            'amount' => $request->validated('amount'),
            'mobile_money_provider' => $request->validated('mobile_money_provider'),
            'gateway_reference' => (string) Str::uuid(),
        ]);

        try {
            $result = $this->gateway->initiateCharge(
                $payment->gateway_reference,
                (float) $payment->amount,
                $payment->mobile_money_provider,
                $request->validated('phone_number'),
            );
        } catch (MobileMoneyGatewayException $e) {
            $payment->update(['status' => 'failed', 'raw_gateway_payload' => ['error' => $e->getMessage()]]);

            return new PaymentResource($payment);
        }

        $payment->update([
            'status' => $result->initiated ? 'pending_confirmation' : 'failed',
            'raw_gateway_payload' => $result->rawPayload,
        ]);

        return new PaymentResource($payment);
    }
}
