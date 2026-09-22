<?php

namespace App\Models;

use App\Services\Geo\GeoPoint;
use Carbon\CarbonInterface;
use Database\Factories\JobLocationSnapshotFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A throttled route-replay point (Backend Schema §2.9) — written roughly
 * every few minutes while a job's truck is reporting position, never per
 * raw ping (TRD §5.2). Nothing reads this back yet (the live map reads
 * Truck::last_known_*); it exists for a future dispute/route-replay view.
 *
 * `location` is deliberately NOT fillable — it's a raw PostGIS expression
 * (see GeoPoint), set only via setAttribute() in [record()], the same
 * reason Job never mass-assigns pickup_location/dropoff_location either.
 */
#[Fillable(['job_id', 'job_award_id', 'truck_id', 'recorded_at'])]
class JobLocationSnapshot extends Model
{
    /** @use HasFactory<JobLocationSnapshotFactory> */
    use HasFactory;

    public $timestamps = false;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'recorded_at' => 'datetime',
        ];
    }

    /**
     * $recordedAt is the position's own timestamp (when the GPS provider
     * says the vehicle was there), NOT wall-clock "now" — a route-replay
     * log has to reflect when the truck was actually at that point, not
     * whenever our queue happened to get around to processing it.
     */
    public static function record(int $jobId, int $truckId, GeoPoint $point, ?CarbonInterface $recordedAt = null, ?int $jobAwardId = null): self
    {
        $snapshot = new self([
            'job_id' => $jobId,
            'job_award_id' => $jobAwardId,
            'truck_id' => $truckId,
            'recorded_at' => $recordedAt ?? now(),
        ]);
        $snapshot->setAttribute('location', $point->toInsertExpression());
        $snapshot->save();

        return $snapshot;
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    public function jobAward(): BelongsTo
    {
        return $this->belongsTo(JobAward::class);
    }

    public function truck(): BelongsTo
    {
        return $this->belongsTo(Truck::class);
    }
}
