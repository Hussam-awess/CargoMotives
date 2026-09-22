<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A transporter company following a specific customer (Phase: Follow
 * system) — see the migration's docblock for why this exists. Append-only
 * in practice: unfollowing deletes the row rather than flipping a status.
 */
#[Fillable(['transporter_company_id', 'customer_id'])]
class CustomerFollow extends Model
{
    const UPDATED_AT = null;

    public function transporterCompany(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }
}
