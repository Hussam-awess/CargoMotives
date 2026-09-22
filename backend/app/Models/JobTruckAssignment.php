<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One truck+driver pair on a multi-truck job's roster (Bulk Cargo epic) —
 * only ever created for jobs.trucks_needed > 1; see the migration's
 * docblock for is_lead's meaning.
 */
#[Fillable(['job_id', 'job_award_id', 'truck_id', 'driver_id', 'driver_link_id', 'is_lead', 'assigned_at'])]
class JobTruckAssignment extends Model
{
    protected function casts(): array
    {
        return [
            'is_lead' => 'boolean',
            'assigned_at' => 'datetime',
        ];
    }

    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class);
    }

    /**
     * Multi-Company Split Awards epic: set only when this roster row
     * belongs to one company's award rather than directly to the job —
     * see the migration's docblock.
     */
    public function jobAward(): BelongsTo
    {
        return $this->belongsTo(JobAward::class);
    }

    // withTrashed() on both, same reasoning as Job::assignedTruck()/
    // assignedDriver() — a completed multi-truck job's roster must keep
    // resolving even after a truck/driver later leaves the fleet.
    public function truck(): BelongsTo
    {
        return $this->belongsTo(Truck::class)->withTrashed();
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class)->withTrashed();
    }

    public function driverLink(): BelongsTo
    {
        return $this->belongsTo(DriverLink::class);
    }
}
