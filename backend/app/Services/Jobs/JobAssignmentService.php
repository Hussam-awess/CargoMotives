<?php

namespace App\Services\Jobs;

use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\Truck;
use App\Services\Sms\SmsGateway;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Assigning a truck + driver to an already-bid-accepted job (AppFlow §2.5).
 * Deliberately separate from BidController::accept() (Phase 4): accepting a
 * bid commits a *company* to a job; this is the finer-grained step of
 * picking which truck and driver actually execute it, and can happen again
 * later (a truck breakdown mid-job) without re-running the bidding flow.
 *
 * Every assignment (first-time or a reassignment) issues a fresh DriverLink
 * and immediately invalidates any still-active one for the job — a driver
 * link that was texted to the wrong/replaced driver must stop working the
 * moment someone else is assigned.
 */
class JobAssignmentService
{
    /**
     * Job statuses in which an assignment (or reassignment) may still
     * happen — anything from "a company has committed to it" up to, but
     * not including, "delivery has been submitted". Kept as an explicit
     * allow-list rather than a single != check so a status added later
     * (e.g. Phase 6 GPS states) doesn't silently fall through this gate.
     */
    private const ASSIGNABLE_STATUSES = ['assigned', 'en_route_pickup', 'picked_up', 'in_transit'];

    public function __construct(private readonly SmsGateway $sms) {}

    public function assign(Job $job, Truck $truck, Driver $driver): DriverLink
    {
        return DB::transaction(function () use ($job, $truck, $driver) {
            $job = Job::whereKey($job->id)->lockForUpdate()->firstOrFail();

            if (! in_array($job->status, self::ASSIGNABLE_STATUSES, true)) {
                throw ValidationException::withMessages([
                    'status' => ['A truck and driver can only be assigned to a job that has been accepted but not yet delivered.'],
                ]);
            }

            // Business Rule #3 (Backend Schema §4): a truck must be its own
            // company's, approved, and idle — unless it's already the truck
            // on this very job (reassigning just the driver, or re-sending
            // the link, shouldn't be blocked by the truck being "on_job"
            // because of this same job).
            $truckAvailable = $truck->current_status === 'idle' || $job->assigned_truck_id === $truck->id;
            if ($truck->verification_status !== 'approved' || ! $truckAvailable) {
                throw ValidationException::withMessages([
                    'truck_id' => ['This truck is not available for assignment.'],
                ]);
            }

            if (! $driver->is_active) {
                throw ValidationException::withMessages([
                    'driver_id' => ['This driver is not active.'],
                ]);
            }

            // Free up whichever truck was previously on this job, if it's
            // being swapped out.
            if ($job->assigned_truck_id !== null && $job->assigned_truck_id !== $truck->id) {
                Truck::whereKey($job->assigned_truck_id)->update(['current_status' => 'idle']);
            }

            $truck->update(['current_status' => 'on_job']);
            $job->update([
                'assigned_truck_id' => $truck->id,
                'assigned_driver_id' => $driver->id,
                // Phase 6 (TRD §5.3): whether this job gets a live map at
                // all is decided right here, once, from the truck's own
                // GPS state — not re-derived on every read. 'ok' is
                // optimistic (the truck has a live connection; a real
                // sweep — App\Console\Commands\CheckGpsSignalLoss — is
                // what actually catches a feed going quiet later).
                'gps_tracking_active' => $truck->isGpsConnected(),
                'gps_signal_status' => $truck->isGpsConnected() ? 'ok' : 'not_applicable',
                // The reference point CheckGpsSignalLoss uses to catch a
                // truck that never sends a single real position at all —
                // last_known_at itself stays NULL in that case, so there's
                // nothing else to measure elapsed time against.
                'gps_tracking_started_at' => $truck->isGpsConnected() ? now() : null,
            ]);

            // Any link still active for this job (a previous assignment)
            // must stop working the instant a new one is issued.
            DriverLink::where('job_id', $job->id)->where('status', 'active')->update(['status' => 'expired']);

            $link = DriverLink::create([
                'job_id' => $job->id,
                'driver_id' => $driver->id,
                'token' => Str::random(48),
                'expires_at' => now()->addDays((int) config('driver_link.expiry_days', 14)),
            ]);

            // SMS failure degrades silently here (TRD §5.3) — the caller
            // always gets the link back (JobAssignmentController exposes
            // it via DriverLinkResource) so the company app can display or
            // re-share it regardless of whether the text itself went out.
            $this->sms->send(
                $driver->phone_number,
                "You've been assigned Job #{$job->id}: {$job->pickup_address} -> {$job->dropoff_address}. Open: ".$link->url()
            );

            return $link;
        });
    }
}
