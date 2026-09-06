<?php

namespace App\Http\Resources;

use App\Models\CommissionLedger;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin CommissionLedger
 */
class CommissionLedgerEntryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'entry_type' => $this->entry_type,
            'amount' => (float) $this->amount,
            'balance_after' => (float) $this->balance_after,
            'related_job_id' => $this->related_job_id,
            'payment_id' => $this->payment_id,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
