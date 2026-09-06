<?php

namespace App\Models;

use Database\Factories\PaymentFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A mobile money payment attempt (Backend Schema §2.14) — commission
 * paydowns only in Phase 7; featured_company/featured_customer purposes
 * exist on the enum already but nothing writes them until Phase 8.
 * `gateway_reference` is this app's own idempotency key (Business Rule
 * §8), not one Selcom assigns — generated once at creation, sent to the
 * gateway as the order id, and echoed back on its webhook so a retried
 * delivery can be recognized as the same payment.
 */
#[Fillable(['user_id', 'purpose', 'amount', 'mobile_money_provider', 'gateway_reference', 'status', 'raw_gateway_payload'])]
class Payment extends Model
{
    /** @use HasFactory<PaymentFactory> */
    use HasFactory;

    /**
     * @var array<string, mixed>
     */
    protected $attributes = [
        'status' => 'initiated',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'raw_gateway_payload' => 'array',
        ];
    }

    public function payer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
