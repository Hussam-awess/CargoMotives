<?php

namespace App\Models;

use Database\Factories\ProofOfDeliveryFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A driver's delivery submission via their Driver Link (Backend Schema
 * §2.10). Photo keys are private-storage paths (App\Services\Documents\
 * DocumentStorage), never public URLs — resolved to temporary signed URLs
 * only in App\Http\Resources\ProofOfDeliveryResource, the same pattern
 * already used for company/truck verification documents.
 */
#[Fillable(['job_id', 'job_award_id', 'driver_id', 'driver_link_id', 'photo_urls', 'recipient_name', 'notes', 'is_system_generated'])]
class ProofOfDelivery extends Model
{
    /** @use HasFactory<ProofOfDeliveryFactory> */
    use HasFactory;

    protected $attributes = [
        'is_system_generated' => false,
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'photo_urls' => 'array',
            'confirmed_by_customer_at' => 'datetime',
            'is_system_generated' => 'boolean',
        ];
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    /**
     * Multi-Company Split Awards epic: set only when this PoD belongs to
     * one company's award rather than directly to the job.
     */
    public function jobAward(): BelongsTo
    {
        return $this->belongsTo(JobAward::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }

    public function driverLink(): BelongsTo
    {
        return $this->belongsTo(DriverLink::class);
    }
}
