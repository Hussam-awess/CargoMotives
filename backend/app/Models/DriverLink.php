<?php

namespace App\Models;

use Database\Factories\DriverLinkFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Facades\URL;

/**
 * A single-use, short-lived, no-login token scoped to exactly one job
 * (Backend Schema §2.5, TRD §7: "a separate short-lived signed token for
 * the Driver Link ... never a Sanctum token"). This table — not the auth
 * system — is the entire source of truth for whether a token may act on a
 * job: see App\Services\Jobs\JobAssignmentService (issues one on
 * assignment) and App\Http\Controllers\DriverLink\DriverLinkPageController
 * (validates one on every request).
 */
#[Fillable(['job_id', 'driver_id', 'token', 'status', 'expires_at', 'used_at'])]
class DriverLink extends Model
{
    /** @use HasFactory<DriverLinkFactory> */
    use HasFactory;

    /**
     * @var array<string, mixed>
     */
    protected $attributes = [
        'status' => 'active',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'used_at' => 'datetime',
        ];
    }

    /**
     * Whether this link may still be used to view/act on its job. Time
     * expiry is checked here (not just the `status` column) since a link
     * can pass its expires_at without anything having proactively flipped
     * its status row — the check has to be correct at read time regardless
     * of whether a background sweep ever ran.
     */
    public function isValid(): bool
    {
        return $this->status === 'active' && $this->expires_at->isFuture();
    }

    /**
     * The public, no-login URL this token opens. Lives on the model (not
     * JobAssignmentService or the resource) since it needs nothing but the
     * token itself — every caller that has a DriverLink can build its URL
     * without a service lookup.
     */
    public function url(): string
    {
        return URL::to("/driver-link/{$this->token}");
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    public function driver(): BelongsTo
    {
        // withTrashed(): an old (expired/used) link must keep resolving
        // its driver even after the company later removes that driver
        // from its roster — same reasoning as Job::assignedDriver().
        return $this->belongsTo(Driver::class)->withTrashed();
    }

    public function proofOfDelivery(): HasOne
    {
        return $this->hasOne(ProofOfDelivery::class);
    }
}
