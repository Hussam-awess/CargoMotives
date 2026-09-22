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
    'trucks_needed', 'approx_weight_tons', 'cargo_description', 'preferred_pickup_window_start', 'preferred_pickup_window_end',
    'customer_notes', 'budget_price', 'currency', 'photo_urls', 'assigned_company_id', 'assigned_bid_id', 'assigned_truck_id',
    'assigned_driver_id', 'agreed_price', 'cancelled_reason', 'gps_tracking_active', 'gps_signal_status',
    'gps_tracking_started_at', 'bidding_expires_at',
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
        'trucks_needed' => 1,
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
            'budget_price' => 'decimal:2',
            'agreed_price' => 'decimal:2',
            'preferred_pickup_window_start' => 'datetime',
            'preferred_pickup_window_end' => 'datetime',
            'gps_tracking_active' => 'boolean',
            'gps_tracking_started_at' => 'datetime',
            'completed_at' => 'datetime',
            'bidding_expires_at' => 'datetime',
            'bidding_expiry_notified_at' => 'datetime',
            'dropoff_arrival_notified_at' => 'datetime',
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

    // withTrashed() on both: a company can now remove a truck/driver once
    // idle (TruckController::destroy(), DriverController::destroy()), but
    // a job's own historical record — including a completed one from
    // months ago — must keep showing which truck/driver actually did the
    // work regardless of later fleet changes.
    public function assignedTruck(): BelongsTo
    {
        return $this->belongsTo(Truck::class, 'assigned_truck_id')->withTrashed();
    }

    public function assignedDriver(): BelongsTo
    {
        return $this->belongsTo(Driver::class, 'assigned_driver_id')->withTrashed();
    }

    public function bids(): HasMany
    {
        return $this->hasMany(Bid::class, 'job_id');
    }

    public function driverLinks(): HasMany
    {
        return $this->hasMany(DriverLink::class);
    }

    /**
     * The full multi-truck roster (Bulk Cargo epic) — only ever populated
     * for trucks_needed > 1; an ordinary job's roster is always empty (its
     * single truck/driver lives on assignedTruck()/assignedDriver() instead).
     */
    public function truckAssignments(): HasMany
    {
        return $this->hasMany(JobTruckAssignment::class);
    }

    /**
     * Multi-Company Split Awards epic: one row per company that ended up
     * covering only PART of trucks_needed — empty for every ordinary job
     * and for a bulk job fully covered by a single company's bid (those
     * keep using assigned_company_id/assigned_bid_id exactly as before
     * this epic; see BidController::accept()).
     */
    public function awards(): HasMany
    {
        return $this->hasMany(JobAward::class);
    }

    /**
     * Whether this job needs more than one truck — the single switch that
     * decides whether JobAssignmentService/DriverLinkPageController/
     * confirmDelivery() use the roster path or leave today's single-truck
     * behavior completely untouched.
     */
    public function isMultiTruck(): bool
    {
        return $this->trucks_needed > 1;
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
     * Distinct transporter companies that have opened this job's detail
     * (Cargo Motives Plus benefit: job view counts) — see JobView's
     * docblock.
     */
    public function jobViews(): HasMany
    {
        return $this->hasMany(JobView::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    public function disputes(): HasMany
    {
        return $this->hasMany(Dispute::class);
    }

    /**
     * Job statuses a truck could plausibly be reporting a live position
     * for — from the moment it's assigned (already en route to pickup in
     * practice, even before the driver marks that via the Driver Link)
     * through delivery. Mirrors JobAssignmentService::ASSIGNABLE_STATUSES.
     */
    public function isGpsTrackable(): bool
    {
        return in_array($this->status, ['assigned', 'en_route_pickup', 'picked_up', 'in_transit'], true);
    }

    /**
     * Bidding Deadline epic: a computed state, never stored — jobs.status
     * stays 'open' the entire time a deadline is in effect, so this is
     * purely `bidding_expires_at` compared against now(). Null (every job
     * posted before this feature existed, or one that never got a
     * deadline) means "never closes on its own," matching today's
     * indefinite-until-accepted behavior exactly. Once status moves past
     * 'open' — accepted, cancelled, or (Multi-Company Split Awards epic)
     * fully covered — the deadline becomes irrelevant, since bidding has
     * already ended for a different reason.
     */
    public function isBiddingClosed(): bool
    {
        return $this->status === 'open' && $this->bidding_expires_at !== null && $this->bidding_expires_at->isPast();
    }

    /**
     * A public profile's "recent completed jobs" (Phase: public profiles)
     * — always anonymized on every copy, for every viewer: no job id, no
     * counterparty name/company, since any authenticated user can view any
     * profile, not just someone who actually worked with this party. The
     * "route" is a rough city/area approximation (the first comma-segment
     * of each address) — there's no structured city field on a job today,
     * so this is a pragmatic stand-in, not a real geocode.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function recentCompletedSummariesFor(string $column, int $id, int $limit = 5): array
    {
        return static::where($column, $id)
            ->where('status', 'completed')
            ->whereNotNull('completed_at')
            ->latest('completed_at')
            ->limit($limit)
            ->get(['completed_at', 'container_type', 'pickup_address', 'dropoff_address'])
            ->map(fn (self $job) => [
                'completed_at' => $job->completed_at->toIso8601String(),
                'container_type' => $job->container_type,
                'route' => self::firstAddressSegment($job->pickup_address).' → '.self::firstAddressSegment($job->dropoff_address),
            ])
            ->all();
    }

    private static function firstAddressSegment(string $address): string
    {
        return trim(explode(',', $address)[0]);
    }
}
