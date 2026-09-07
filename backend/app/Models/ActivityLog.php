<?php

namespace App\Models;

use Database\Factories\ActivityLogFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/**
 * One row of the marketplace's audit trail (Backend Schema §2.16). Always
 * written through App\Services\ActivityLog\ActivityLogger — see that
 * class, and the model observers that call it (App\Observers\*) — never
 * created directly, so every future phase's state changes get logged the
 * same way without each controller having to remember to call this.
 *
 * Append-only: no updated_at (an entry is never edited once written).
 */
#[Fillable(['actor_user_id', 'action', 'subject_type', 'subject_id', 'metadata'])]
class ActivityLog extends Model
{
    /** @use HasFactory<ActivityLogFactory> */
    use HasFactory;

    const UPDATED_AT = null;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'metadata' => 'array',
        ];
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }

    public function subject(): MorphTo
    {
        return $this->morphTo();
    }
}
