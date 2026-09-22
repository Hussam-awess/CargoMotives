<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A transporter company having opened a specific job's detail (Cargo
 * Motives Plus benefit: job view counts). See the migration's docblock —
 * deduplicated per (job, company), so this is a distinct-viewer count, not
 * a page-load counter.
 */
#[Fillable(['job_id', 'transporter_company_id'])]
class JobView extends Model
{
    const UPDATED_AT = null;

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    public function transporterCompany(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class);
    }
}
