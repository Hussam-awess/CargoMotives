<?php

namespace App\Models;

use Database\Factories\DisputeFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A customer's "Report a Problem" on a delivered job (Backend Schema
 * §2.12) — the AppFlow alternative to JobController::confirmDelivery().
 * Admin's Disputes tool (PRD §10 item 8) reviews it against the job's
 * proof of delivery and (when available) GPS history, then resolves it.
 */
#[Fillable(['job_id', 'raised_by_user_id', 'reason', 'status', 'resolution_note', 'resolved_by_admin_id', 'resolved_at'])]
class Dispute extends Model
{
    /** @use HasFactory<DisputeFactory> */
    use HasFactory;

    /**
     * Mirrors the migration's column default — see User::$attributes for
     * why this is necessary.
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        'status' => 'open',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'resolved_at' => 'datetime',
        ];
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    public function raisedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'raised_by_user_id');
    }

    public function resolvedByAdmin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by_admin_id');
    }
}
