<?php

namespace App\Models;

use Database\Factories\TransporterCompanyFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A verified (or verification-pending) transporter company and its one
 * verified representative (Backend Schema §2.2 — merged from a separate
 * company_representatives table since MVP only needs one rep per company).
 */
#[Fillable([
    'owner_user_id', 'company_name', 'registration_number', 'tin', 'physical_address', 'company_phone', 'company_email',
    'logo_url', 'documents', 'rep_full_name', 'rep_position', 'rep_national_id_number',
    'rep_id_document_url', 'rep_selfie_url', 'rep_phone_verified', 'rep_email_verified',
    'verification_status', 'verification_rejected_reason', 'verified_at',
])]
class TransporterCompany extends Model
{
    /** @use HasFactory<TransporterCompanyFactory> */
    use HasFactory;

    /**
     * Mirrors the migration's column defaults — see User::$attributes for
     * why this is necessary (Eloquent's create() doesn't reflect DB-level
     * defaults on the returned in-memory model otherwise).
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        'rep_phone_verified' => false,
        'rep_email_verified' => false,
        'verification_status' => 'pending',
        'is_featured' => false,
        'rating_count' => 0,
        'outstanding_balance' => 0,
        'commission_standing' => 'good_standing',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'documents' => 'array',
            'preferred_routes' => 'array',
            'rep_phone_verified' => 'boolean',
            'rep_email_verified' => 'boolean',
            'is_featured' => 'boolean',
            'featured_until' => 'datetime',
            'verified_at' => 'datetime',
            'average_rating' => 'decimal:1',
            'outstanding_balance' => 'decimal:2',
        ];
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_user_id');
    }

    public function trucks(): HasMany
    {
        return $this->hasMany(Truck::class, 'transporter_company_id');
    }

    public function drivers(): HasMany
    {
        return $this->hasMany(Driver::class, 'transporter_company_id');
    }

    public function bids(): HasMany
    {
        return $this->hasMany(Bid::class, 'transporter_company_id');
    }

    public function gpsConnections(): HasMany
    {
        return $this->hasMany(GpsConnection::class, 'transporter_company_id');
    }

    /**
     * The company-level GPS trust signal shown on a bid (PRD §7.3): "at
     * least one of the company's trucks has GPS connected." Not tied to
     * any specific truck, since bidding happens before a truck is assigned
     * to the job (Phase 5) — there's no per-job truck yet to check.
     *
     * Uses the already-loaded `trucks` relation when available (a bid
     * listing eager-loads company.trucks) rather than a fresh query per
     * company — avoids an N+1 across a job's whole bid list.
     */
    public function hasAnyGpsConnectedTruck(): bool
    {
        if ($this->relationLoaded('trucks')) {
            return $this->trucks->contains('gps_status', 'connected');
        }

        return $this->trucks()->where('gps_status', 'connected')->exists();
    }

    public function verifiedTruckCount(): int
    {
        if ($this->relationLoaded('trucks')) {
            return $this->trucks->where('verification_status', 'approved')->count();
        }

        return $this->trucks()->where('verification_status', 'approved')->count();
    }
}
