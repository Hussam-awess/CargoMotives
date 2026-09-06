<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\InitiateCommissionPaymentRequest;
use App\Http\Resources\CommissionLedgerEntryResource;
use App\Http\Resources\PaymentResource;
use App\Services\MobileMoney\MobileMoneyPaymentInitiator;
use App\Services\Settings\PlatformSettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

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
        private readonly MobileMoneyPaymentInitiator $paymentInitiator,
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
        $payment = $this->paymentInitiator->initiate(
            $request->user()->id,
            'commission_payment',
            (float) $request->validated('amount'),
            $request->validated('mobile_money_provider'),
            $request->validated('phone_number'),
        );

        return new PaymentResource($payment);
    }
}
