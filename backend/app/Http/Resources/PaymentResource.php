<?php

namespace App\Http\Resources;

use App\Models\Payment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Payment
 */
class PaymentResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'purpose' => $this->purpose,
            'amount' => (float) $this->amount,
            'mobile_money_provider' => $this->mobile_money_provider,
            'status' => $this->status,
            // raw_gateway_payload deliberately never exposed — it's an
            // internal debugging record of the gateway's own response,
            // not something the app needs to show a company.
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
