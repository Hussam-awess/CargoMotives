<?php

namespace App\Http\Controllers\Customer;

use App\Http\Controllers\Controller;
use App\Http\Requests\InitiateFeaturedPurchaseRequest;
use App\Http\Resources\PaymentResource;
use App\Services\MobileMoney\MobileMoneyPaymentInitiator;
use App\Services\Settings\PlatformSettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Featured (Customer) — AppFlow §3.6: "Profile → Upgrade to Featured →
 * explains the higher daily post quota → pay via mobile money → unlocks
 * immediately." JobPostQuotaService already reads users.is_featured
 * (Phase 4) — this is only the purchase flow. First controller under a
 * dedicated Customer namespace, mirroring the existing Company one, since
 * this is genuinely account-settings-shaped rather than job-shaped.
 */
class FeaturedController extends Controller
{
    public function __construct(
        private readonly MobileMoneyPaymentInitiator $paymentInitiator,
        private readonly PlatformSettings $settings,
    ) {}

    public function status(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'is_featured' => (bool) $user->is_featured,
            'featured_until' => $user->featured_until?->toIso8601String(),
            'price' => $this->settings->getFloat('customer_featured_price', 5000),
            'duration_days' => $this->settings->getInt('featured_duration_days', 30),
        ]);
    }

    public function purchase(InitiateFeaturedPurchaseRequest $request): PaymentResource
    {
        $payment = $this->paymentInitiator->initiate(
            $request->user()->id,
            'featured_customer',
            $this->settings->getFloat('customer_featured_price', 5000),
            $request->validated('mobile_money_provider'),
            $request->validated('phone_number'),
        );

        return new PaymentResource($payment);
    }
}
