<?php

namespace App\Models;

use Database\Factories\BidFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A company's offer on an open job (Backend Schema §2.8). Only one
 * 'pending' bid per (job, company) pair is allowed — enforced by a partial
 * unique DB index (see the migration), not application logic, since it's a
 * plain race-condition guard with no "flagging" workflow needed.
 */
#[Fillable([
    'job_id', 'transporter_company_id', 'price', 'trucks_offered', 'estimated_pickup_time', 'note', 'status', 'is_priority',
    'is_return_load_claim',
])]
class Bid extends Model
{
    /** @use HasFactory<BidFactory> */
    use HasFactory;

    /**
     * Mirrors the migration's column defaults — see User::$attributes for
     * why this is necessary.
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        'status' => 'pending',
        'is_priority' => false,
        'trucks_offered' => 1,
        'is_return_load_claim' => false,
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'estimated_pickup_time' => 'datetime',
            'is_priority' => 'boolean',
            'is_return_load_claim' => 'boolean',
        ];
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class, 'job_id');
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'transporter_company_id');
    }
}
