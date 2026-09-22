<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One side of a two-way job rating (Phase: ratings) — see the migration's
 * docblock for why a single table covers both directions. Append-only:
 * `rating`/`comment`/`category_ratings` are never edited after submission.
 */
#[Fillable(['job_id', 'rater_type', 'rater_user_id', 'ratee_customer_id', 'ratee_company_id', 'rating', 'comment', 'category_ratings'])]
class JobReview extends Model
{
    const UPDATED_AT = null;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'category_ratings' => 'array',
        ];
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    public function rater(): BelongsTo
    {
        return $this->belongsTo(User::class, 'rater_user_id');
    }

    public function rateeCustomer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'ratee_customer_id');
    }

    public function rateeCompany(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'ratee_company_id');
    }
}
