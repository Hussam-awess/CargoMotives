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
        'verification_status' => 'pending',
        'gps_status' => 'not_connected',
        'current_status' => 'idle',
        'is_active' => true,
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
            'last_known_at' => 'datetime',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'transporter_company_id');
    }
}
