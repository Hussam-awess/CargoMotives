<?php

namespace App\Models;

use Database\Factories\SupportMessageFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One message in a user's standalone Support thread with Admin (Phase
 * 10.15) — distinct from App\Models\Message, which is scoped to one job's
 * Customer<->Company conversation. A Support thread has no job: it's
 * scoped to one user's account for as long as they hold it, and Admin can
 * write into any user's thread (one at a time, or broadcast — one row per
 * recipient either way).
 *
 * Immutable once sent (no updated_at, matching Message's precedent).
 */
#[Fillable(['user_id', 'author', 'admin_id', 'body'])]
class SupportMessage extends Model
{
    /** @use HasFactory<SupportMessageFactory> */
    use HasFactory;

    const UPDATED_AT = null;

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function admin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_id');
    }
}
