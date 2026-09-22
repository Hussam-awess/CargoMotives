<?php

namespace App\Services\Jobs;

use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobTruckAssignment;
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
 *
 * Bulk Cargo epic: a job with trucks_needed > 1 goes through assignToRoster()
 * instead — it *adds* a truck+driver pair to job_truck_assignments rather
 * than replacing the job's single slot, since a 20-truck job legitimately
 * has 20 trucks in flight at once. assign() itself (the trucks_needed <= 1
 * path below) is completely unchanged from before that epic.
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

    /**
     * $award (Multi-Company Split Awards epic) is non-null only when the
     * calling company holds one of the job's awards rather than being the
     * sole legacy-assigned company — every existing call site omits it and
     * is completely unaffected.
     */
    public function assign(Job $job, Truck $truck, Driver $driver, ?JobAward $award = null): DriverLink
    {
        return DB::transaction(function () use ($job, $truck, $driver, $award) {
            $job = Job::whereKey($job->id)->lockForUpdate()->firstOrFail();

            if ($award !== null) {
                $award = JobAward::whereKey($award->id)->lockForUpdate()->firstOrFail();

                // The award has its OWN fulfillment timeline, independent
                // of the job's — a company awarded 8 of 20 trucks must be
                // able to start moving its own trucks immediately, not
                // wait for the job's other capacity to be covered (which
                // could take a while, or never happen).
                if (! in_array($award->status, self::ASSIGNABLE_STATUSES, true)) {
                    throw ValidationException::withMessages([
                        'status' => ['A truck and driver can only be assigned while this award has been accepted but not yet delivered.'],
                    ]);
                }

                return $this->assignToAwardRoster($job, $award, $truck, $driver);
            }

            if ($job->isMultiTruck()) {
                // Bulk Cargo epic: a multi-truck job's roster is built up
                // incrementally — the lead truck may already be en route
                // while later trucks are still being added, so this stays
                // on the broader ASSIGNABLE_STATUSES gate, not the
                // stricter "assigned only" one below. This only ever adds
                // a new roster member; it never swaps an existing one, so
                // "can't reassign once active" doesn't apply here.
                if (! in_array($job->status, self::ASSIGNABLE_STATUSES, true)) {
                    throw ValidationException::withMessages([
                        'status' => ['A truck and driver can only be assigned to a job that has been accepted but not yet delivered.'],
                    ]);
                }

                return $this->assignToRoster($job, $truck, $driver);
            }

            // An ordinary (single-truck) job's truck/driver can be set or
            // changed only before the job has actually started — once the
            // driver has advanced past 'assigned' (en_route_pickup and
            // beyond), the truck already in motion can't be swapped out
            // from under the shipment. First-time assignment is
            // unaffected: a job is always still 'assigned' the moment its
            // bid is accepted, before any truck exists on it yet.
            if ($job->status !== 'assigned') {
                throw ValidationException::withMessages([
                    'status' => ['The truck and driver can only be assigned or changed before the job has started.'],
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

    /**
     * Adds one truck+driver pair to a multi-truck job's roster (Bulk Cargo
     * epic) — called from within assign()'s already-locked transaction, so
     * no separate lock/status check here. Unlike assign()'s swap semantics,
     * this never releases another truck and never expires another roster
     * member's DriverLink: a 20-truck job's trucks are all legitimately
     * in flight at once, so adding truck #2 must not disturb truck #1.
     */
    private function assignToRoster(Job $job, Truck $truck, Driver $driver): DriverLink
    {
        $rosterCount = JobTruckAssignment::where('job_id', $job->id)->count();

        if ($rosterCount >= $job->trucks_needed) {
            throw ValidationException::withMessages([
                'truck_id' => ["This job's fleet is already fully assigned ({$job->trucks_needed}/{$job->trucks_needed})."],
            ]);
        }

        if (JobTruckAssignment::where('job_id', $job->id)->where('truck_id', $truck->id)->exists()) {
            throw ValidationException::withMessages([
                'truck_id' => ['This truck is already on this job\'s roster.'],
            ]);
        }

        if ($truck->verification_status !== 'approved' || $truck->current_status !== 'idle') {
            throw ValidationException::withMessages([
                'truck_id' => ['This truck is not available for assignment.'],
            ]);
        }

        if (! $driver->is_active) {
            throw ValidationException::withMessages([
                'driver_id' => ['This driver is not active.'],
            ]);
        }

        $isLead = $rosterCount === 0;

        $truck->update(['current_status' => 'on_job']);

        // Deliberately does NOT touch any other DriverLink for this job —
        // see the class docblock. Every roster truck gets its own link so
        // its driver can see pickup/dropoff details, but only the lead's
        // link can advance the job's shared status (DriverLinkPageController
        // enforces that).
        $link = DriverLink::create([
            'job_id' => $job->id,
            'driver_id' => $driver->id,
            'token' => Str::random(48),
            'expires_at' => now()->addDays((int) config('driver_link.expiry_days', 14)),
        ]);

        JobTruckAssignment::create([
            'job_id' => $job->id,
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'is_lead' => $isLead,
            'assigned_at' => now(),
        ]);

        if ($isLead) {
            $job->update([
                'assigned_truck_id' => $truck->id,
                'assigned_driver_id' => $driver->id,
                'gps_tracking_active' => $truck->isGpsConnected(),
                'gps_signal_status' => $truck->isGpsConnected() ? 'ok' : 'not_applicable',
                'gps_tracking_started_at' => $truck->isGpsConnected() ? now() : null,
            ]);
        }

        $this->sms->send(
            $driver->phone_number,
            "You've been assigned Job #{$job->id}: {$job->pickup_address} -> {$job->dropoff_address}. Open: ".$link->url()
        );

        return $link;
    }

    /**
     * Adds one truck+driver pair to ONE company's own award roster
     * (Multi-Company Split Awards epic) — a straight copy of
     * assignToRoster()'s shape, scoped to job_award_id instead of job_id
     * throughout, and writing the award's own GPS/lead fields rather than
     * the job's. Never touches another award's (i.e. another company's)
     * trucks, links, or state.
     */
    private function assignToAwardRoster(Job $job, JobAward $award, Truck $truck, Driver $driver): DriverLink
    {
        $rosterCount = JobTruckAssignment::where('job_award_id', $award->id)->count();

        if ($rosterCount >= $award->trucks_offered) {
            throw ValidationException::withMessages([
                'truck_id' => ["This award's fleet is already fully assigned ({$award->trucks_offered}/{$award->trucks_offered})."],
            ]);
        }

        if (JobTruckAssignment::where('job_award_id', $award->id)->where('truck_id', $truck->id)->exists()) {
            throw ValidationException::withMessages([
                'truck_id' => ['This truck is already on this award\'s roster.'],
            ]);
        }

        if ($truck->verification_status !== 'approved' || $truck->current_status !== 'idle') {
            throw ValidationException::withMessages([
                'truck_id' => ['This truck is not available for assignment.'],
            ]);
        }

        if (! $driver->is_active) {
            throw ValidationException::withMessages([
                'driver_id' => ['This driver is not active.'],
            ]);
        }

        $isLead = $rosterCount === 0;

        $truck->update(['current_status' => 'on_job']);

        // Deliberately does NOT touch any other DriverLink, on this award
        // or any other award on the same job — each company's roster
        // (and each truck within it) is fully independent.
        $link = DriverLink::create([
            'job_id' => $job->id,
            'driver_id' => $driver->id,
            'token' => Str::random(48),
            'expires_at' => now()->addDays((int) config('driver_link.expiry_days', 14)),
        ]);

        JobTruckAssignment::create([
            'job_id' => $job->id,
            'job_award_id' => $award->id,
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'is_lead' => $isLead,
            'assigned_at' => now(),
        ]);

        if ($isLead) {
            $award->update([
                'gps_tracking_active' => $truck->isGpsConnected(),
                'gps_signal_status' => $truck->isGpsConnected() ? 'ok' : 'not_applicable',
                'gps_tracking_started_at' => $truck->isGpsConnected() ? now() : null,
            ]);
        }

        $this->sms->send(
            $driver->phone_number,
            "You've been assigned Job #{$job->id}: {$job->pickup_address} -> {$job->dropoff_address}. Open: ".$link->url()
        );

        return $link;
    }
}
