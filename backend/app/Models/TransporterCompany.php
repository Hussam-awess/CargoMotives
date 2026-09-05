<?php

namespace App\Models;

use Database\Factories\TransporterCompanyFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

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
}
