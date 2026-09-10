<?php

namespace App\Models;

use Database\Factories\NotificationFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * An in-app notification (Backend Schema §2.18) — always created through
 * App\Services\Notifications\NotificationService, never directly, so a
 * push attempt is never forgotten alongside it. Deliberately a completely
 * separate system from Laravel's own built-in notifications package (which
 * this app does not use) — no Notifiable trait, no notifications-table
 * naming collision beyond a coincidental table name matching the schema
 * doc's own choice.
 *
 * Append-only apart from read_at/sent_via_fcm — no updated_at.
 */
#[Fillable(['user_id', 'type', 'title', 'body', 'related_job_id', 'sent_via_fcm', 'read_at'])]
class Notification extends Model
{
    /** @use HasFactory<NotificationFactory> */
    use HasFactory;

    const UPDATED_AT = null;

    protected function casts(): array
    {
        return [
            'sent_via_fcm' => 'boolean',
            'read_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function relatedJob(): BelongsTo
    {
        return $this->belongsTo(Job::class, 'related_job_id');
    }
}
