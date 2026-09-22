<?php

namespace App\Models;

use Database\Factories\TruckFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * A company-owned truck, verified independently of the company itself
 * (Backend Schema §2.3). GPS fields exist on this model from Phase 3
 * onward but stay at their defaults until Phase 6 — see the migration's
 * comments for why they're created this early.
 */
#[Fillable([
    'transporter_company_id', 'registration_number', 'make_model', 'vehicle_type', 'capacity_tons',
    'documents', 'verification_status', 'verification_rejected_reason', 'current_status',
    'gps_status', 'gps_connection_id', 'gps_unit_id', 'last_known_lat', 'last_known_lng',
    'last_known_heading', 'last_known_speed_kmh', 'stationary_since', 'last_known_at', 'gps_driver_name',
    'gps_raw_driver_name', 'is_gps_imported',
])]
class Truck extends Model
{
    /** @use HasFactory<TruckFactory> */
    use HasFactory, SoftDeletes;

    /**
     * Mirrors the migration's column defaults — see User::$attributes for
     * why this is necessary (Eloquent's create() doesn't reflect DB-level
     * defaults on the returned in-memory model otherwise). This is the
     * exact bug that surfaced this pattern: a freshly-created Truck's
     * gps_status/current_status/is_active were null in the API response
     * (live-tested against the real stack) despite the DB row having the
     * correct defaults.
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        // Truck review was removed — a registered truck is usable straight
        // away rather than waiting on an Admin queue. The column itself is
        // kept (JobAssignmentService and verifiedTruckCount() still read
        // it) so the review step can be reinstated later without a
        // migration; nothing writes anything but 'approved' today.
        'verification_status' => 'approved',
        'gps_status' => 'not_connected',
        'current_status' => 'idle',
        'is_active' => true,
        'is_gps_imported' => false,
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'documents' => 'array',
            'capacity_tons' => 'decimal:2',
            'is_active' => 'boolean',
            'is_gps_imported' => 'boolean',
            'last_known_lat' => 'decimal:6',
            'last_known_lng' => 'decimal:6',
            'last_known_heading' => 'decimal:2',
            'last_known_speed_kmh' => 'decimal:2',
            'stationary_since' => 'datetime',
            'last_known_at' => 'datetime',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'transporter_company_id');
    }

    public function gpsConnection(): BelongsTo
    {
        return $this->belongsTo(GpsConnection::class);
    }

    public function isGpsConnected(): bool
    {
        return $this->gps_status === 'connected';
    }

    /**
     * Whether this truck's GPS is actively reporting right now, not just
     * nominally "connected" — a connection can go quiet for a long time
     * (device powered off, out of signal) while gps_status stays
     * 'connected' forever, since that flag only reflects the provider link
     * itself. Same threshold as CheckGpsSignalLoss's job-level check, so
     * "online" means the same thing everywhere it's shown.
     */
    public function isGpsOnline(): bool
    {
        return $this->gps_status === 'connected'
            && $this->last_known_at !== null
            && $this->last_known_at->gte(now()->subMinutes((int) config('gps.signal_lost_after_minutes', 10)));
    }

    /**
     * Green vs. red on the fleet map: true only while the GPS is online AND
     * either currently moving (stationary_since is null, meaning the most
     * recent ping was above the "slow" threshold) or hasn't been slow for
     * long enough yet to count as stationary. A truck with no signal at all
     * reads as "not moving" the same as one parked and reporting fine — the
     * map only distinguishes moving from everything else, not why.
     */
    public function isMoving(): bool
    {
        if (! $this->isGpsOnline()) {
            return false;
        }

        if ($this->stationary_since === null) {
            return true;
        }

        return $this->stationary_since->gt(now()->subMinutes((int) config('gps.stationary_after_minutes', 15)));
    }
}
