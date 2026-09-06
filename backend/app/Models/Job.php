<?php

namespace App\Models;

use App\Services\Geo\GeoPoint;
use Database\Factories\JobFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\DB;

/**
 * A shipment request (Backend Schema §2.7). pickup_location/dropoff_location
 * are real PostGIS geography columns, but — see App\Services\Geo\GeoPoint —
 * Eloquent has no built-in cast for them, so this model never exposes them
 * as plain attributes. Always query through scopeWithCoordinates() to get
 * pickup_lat/pickup_lng/dropoff_lat/dropoff_lng as ordinary floats instead.
 */
#[Fillable([
    'customer_id', 'status', 'pickup_address', 'dropoff_address', 'container_type', 'container_size',
    'approx_weight_tons', 'cargo_description', 'preferred_pickup_window_start', 'preferred_pickup_window_end',
    'customer_notes', 'photo_urls', 'assigned_company_id', 'assigned_bid_id', 'assigned_truck_id',
    'assigned_driver_id', 'agreed_price', 'cancelled_reason',
])]
class Job extends Model
{
    /** @use HasFactory<JobFactory> */
    use HasFactory, SoftDeletes;

    protected $table = 'jobs';

    /**
     * Mirrors the migration's column defaults — see User::$attributes for
     * why this is necessary.
     *
     * @var array<string, mixed>
     */
    protected $attributes = [
        'status' => 'open',
        'currency' => 'TZS',
        'gps_tracking_active' => false,
        'gps_signal_status' => 'not_applicable',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'photo_urls' => 'array',
            'approx_weight_tons' => 'decimal:2',
            'agreed_price' => 'decimal:2',
            'preferred_pickup_window_start' => 'datetime',
            'preferred_pickup_window_end' => 'datetime',
            'gps_tracking_active' => 'boolean',
        ];
    }

    /**
     * Adds pickup_lat/pickup_lng/dropoff_lat/dropoff_lng to the query's
     * SELECT — the only way this model ever exposes the geography columns'
     * values. Every read path that needs coordinates (JobResource) must
     * query through this scope; nothing else can decode PostGIS's binary
     * point format.
     */
    public function scopeWithCoordinates(Builder $query): Builder
    {
        return $query->addSelect('jobs.*')->addSelect([
            DB::raw('ST_Y(pickup_location::geometry) as pickup_lat'),
            DB::raw('ST_X(pickup_location::geometry) as pickup_lng'),
            DB::raw('ST_Y(dropoff_location::geometry) as dropoff_lat'),
            DB::raw('ST_X(dropoff_location::geometry) as dropoff_lng'),
        ]);
    }

    public function setPickupLocation(GeoPoint $point): void
    {
        $this->setAttribute('pickup_location', $point->toInsertExpression());
    }

    public function setDropoffLocation(GeoPoint $point): void
    {
        $this->setAttribute('dropoff_location', $point->toInsertExpression());
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    public function assignedCompany(): BelongsTo
    {
        return $this->belongsTo(TransporterCompany::class, 'assigned_company_id');
    }

    public function assignedTruck(): BelongsTo
    {
        return $this->belongsTo(Truck::class, 'assigned_truck_id');
    }

    public function assignedDriver(): BelongsTo
    {
        return $this->belongsTo(Driver::class, 'assigned_driver_id');
    }

    public function bids(): HasMany
    {
        return $this->hasMany(Bid::class, 'job_id');
    }

    public function driverLinks(): HasMany
    {
        return $this->hasMany(DriverLink::class);
    }

    public function proofOfDelivery(): HasOne
    {
        return $this->hasOne(ProofOfDelivery::class);
    }
}
