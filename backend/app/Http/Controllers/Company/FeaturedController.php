<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\UpdatePreferredRoutesRequest;
use App\Http\Requests\InitiateFeaturedPurchaseRequest;
use App\Http\Resources\PaymentResource;
use App\Services\MobileMoney\MobileMoneyPaymentInitiator;
use App\Services\Settings\PlatformSettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Featured (Company) — AppFlow §2.7: "From Profile → Upgrade to
 * Featured: explains the higher/faster bid quota, priority placement,
 * fleet map, route filter, and return-load suggestions → pay via mobile
 * money → unlocks immediately." The tools themselves already exist and
 * already read is_featured (BidQuotaService, the is_priority bid flag
 * since Phase 4; the preferred-routes filter, fleet map, and return-load
 * suggestions added alongside this controller in Phase 8) — this
 * controller is only the purchase flow and the one Featured-only setting
 * (preferred routes) a company can edit.
 */
class FeaturedController extends Controller
{
    public function __construct(
        private readonly MobileMoneyPaymentInitiator $paymentInitiator,
        private readonly PlatformSettings $settings,
    ) {}

    public function status(Request $request): JsonResponse
    {
        $company = $request->user()->transporterCompany;

        return response()->json([
            'is_featured' => (bool) $company->is_featured,
            'featured_until' => $company->featured_until?->toIso8601String(),
            'price' => $this->settings->getFloat('company_featured_price', 50000),
            'duration_days' => $this->settings->getInt('featured_duration_days', 30),
            'preferred_routes' => $company->preferred_routes ?? [],
        ]);
    }

    /**
     * Confirmation is asynchronous — see SelcomWebhookController +
     * FeaturedTierService. This only ever pushes the charge.
     */
    public function purchase(InitiateFeaturedPurchaseRequest $request): PaymentResource
    {
        $payment = $this->paymentInitiator->initiate(
            $request->user()->id,
            'featured_company',
            $this->settings->getFloat('company_featured_price', 50000),
            $request->validated('mobile_money_provider'),
            $request->validated('phone_number'),
        );

        return new PaymentResource($payment);
    }

    /**
     * Featured-only (AppFlow §2.7's route filter setting) — a non-Featured
     * company gets a clear 403, not a silently-ignored write.
     */
    public function updatePreferredRoutes(UpdatePreferredRoutesRequest $request): JsonResponse
    {
        $company = $request->user()->transporterCompany;
        abort_unless($company->is_featured, 403, 'Preferred routes are a Featured-only setting.');

        $company->update(['preferred_routes' => $request->validated('routes')]);

        return response()->json(['preferred_routes' => $company->preferred_routes]);
    }
}
