<?php

namespace App\Models;

use Database\Factories\CommissionLedgerFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One entry in a company's commission transaction history (Backend Schema
 * §2.13) — a `charge` (written automatically on job completion) or a
 * `payment` (written when a mobile money payment succeeds). Always
 * created through App\Services\Commission\CommissionLedgerService, never
 * directly — that service is what keeps transporter_companies.
 * outstanding_balance and commission_standing consistent with these rows.
 *
 * Append-only: no `updated_at` (Business Rule intent — a correction is a
 * new entry, never an edit of an old one).
 */
#[Fillable(['transporter_company_id', 'entry_type', 'amount', 'balance_after', 'related_job_id', 'payment_id'])]
class CommissionLedger extends Model
{
    /** @use HasFactory<CommissionLedgerFactory> */
    use HasFactory;

    // Laravel's naming convention would guess "commission_ledgers"
    // (pluralized) — the migration uses the schema doc's literal singular
    // table name instead.
    protected $table = 'commission_ledger';

    const UPDATED_AT = null;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'balance_after' => 'decimal:2',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'transporter_company_id');
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class, 'related_job_id');
    }

    public function payment(): BelongsTo
    {
        return $this->belongsTo(Payment::class);
    }
}
