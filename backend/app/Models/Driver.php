<?php

namespace App\Models;

use Database\Factories\DriverFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * A company's driver roster entry (Backend Schema §2.4). Never an account —
 * a driver acts only through a scoped Driver Link token (Phase 5).
 */
#[Fillable(['transporter_company_id', 'full_name', 'phone_number', 'license_number', 'photo_url', 'is_active'])]
class Driver extends Model
{
    /** @use HasFactory<DriverFactory> */
    use HasFactory, SoftDeletes;

    /**
     * Mirrors the migration's column default — see User::$attributes for
     * why this is necessary.
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        'is_active' => true,
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'transporter_company_id');
    }
}
