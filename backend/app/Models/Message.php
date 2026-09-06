<?php

namespace App\Models;

use Database\Factories\MessageFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One message in a job's conversation (Backend Schema §2.15) — the job
 * itself IS the conversation, so there's no separate conversations table.
 * Deliberately plain REST + refresh-on-open (TRD §4: WebSockets are used
 * for exactly two things — live bids and live GPS — and messaging isn't
 * either of them), not a second real-time channel.
 *
 * Immutable once sent (no updated_at — `const UPDATED_AT = null`); the
 * only thing that ever changes after creation is `read_at`, set once by
 * the *other* party's MessageController::index() call, never the sender's.
 */
#[Fillable(['job_id', 'sender_user_id', 'body'])]
class Message extends Model
{
    /** @use HasFactory<MessageFactory> */
    use HasFactory;

    const UPDATED_AT = null;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'read_at' => 'datetime',
        ];
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_user_id');
    }
}
