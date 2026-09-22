<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * One company's committed slice of a multi-company bulk job (Multi-Company
 * Split Awards epic) — see the migration's docblock for when this exists
 * vs. when a job just uses its own legacy assigned_company_id/assigned_bid_id
 * (a single bid fully covering the job never creates one of these).
 *
 * status/gps_* mirror Job's own equivalent fields but are scoped to this
 * one company's roster — see JobAssignmentService's assignToAwardRoster()
 * and DriverLinkPageController for where they're written.
 */
#[Fillable([
    'job_id', 'bid_id', 'transporter_company_id', 'trucks_offered', 'agreed_price', 'status', 'completed_at',
    'gps_tracking_active', 'gps_signal_status', 'gps_tracking_started_at',
])]
class JobAward extends Model
{
    protected $attributes = [
        'status' => 'assigned',
        'gps_tracking_active' => false,
        'gps_signal_status' => 'not_applicable',
    ];

    protected function casts(): array
    {
        return [
            'agreed_price' => 'decimal:2',
            'gps_tracking_active' => 'boolean',
            'gps_tracking_started_at' => 'datetime',
            'completed_at' => 'datetime',
            'dropoff_arrival_notified_at' => 'datetime',
        ];
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    public function bid(): BelongsTo
    {
        return $this->belongsTo(Bid::class);
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'transporter_company_id');
    }

    public function truckAssignments(): HasMany
    {
        return $this->hasMany(JobTruckAssignment::class);
    }

    /**
     * The one truck+driver pair that drives this award's own shared
     * status/GPS/proof-of-delivery — same "single convoy" simplification
     * Job itself uses for a single company's own multi-truck roster.
     */
    public function leadTruckAssignment(): HasOne
    {
        return $this->hasOne(JobTruckAssignment::class)->where('is_lead', true);
    }

    public function proofOfDelivery(): HasOne
    {
        return $this->hasOne(ProofOfDelivery::class);
    }

    public function locationSnapshots(): HasMany
    {
        return $this->hasMany(JobLocationSnapshot::class);
    }

    /**
     * Mirrors Job::isGpsTrackable() — the statuses in which this award's
     * truck could plausibly be reporting a live position.
     */
    public function isGpsTrackable(): bool
    {
        return in_array($this->status, ['assigned', 'en_route_pickup', 'picked_up', 'in_transit'], true);
    }
}
