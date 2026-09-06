<?php

namespace App\Models;

use Database\Factories\GpsConnectionFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A company's linked GPS provider account (Backend Schema §2.6) — one
 * connection covers the company's whole fleet (TRD §5.1); individual
 * trucks link to it via trucks.gps_connection_id once matched/imported.
 */
#[Fillable(['transporter_company_id', 'provider', 'access_token', 'refresh_token', 'status', 'connected_at', 'last_synced_at'])]
class GpsConnection extends Model
{
    /** @use HasFactory<GpsConnectionFactory> */
    use HasFactory;

    /**
     * @var array<string, mixed>
     */
    protected $attributes = [
        'status' => 'connected',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            // Transparent encrypt/decrypt via APP_KEY (TRD §7: credentials
            // "stored encrypted") — never touched in plaintext outside
            // this model.
            'access_token' => 'encrypted',
            'refresh_token' => 'encrypted',
            'connected_at' => 'datetime',
            'last_synced_at' => 'datetime',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'transporter_company_id');
    }

    public function trucks(): HasMany
    {
        return $this->hasMany(Truck::class, 'gps_connection_id');
    }
}
