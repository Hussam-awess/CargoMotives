<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Jobs\AssignJobRequest;
use App\Http\Resources\DriverLinkResource;
use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobTruckAssignment;
use App\Models\Truck;
use App\Services\Jobs\JobAssignmentService;
use Illuminate\Http\Request;

/**
 * Company assigning a truck + driver to a job it has already won
 * (AppFlow §2.5) — separate from CompanyJobController (browsing/bidding)
 * since this is a distinct concern with its own authorization shape
 * (a company only ever acts on jobs assigned to *it*, never any open job).
 */
class JobAssignmentController extends Controller
{
    public function __construct(private readonly JobAssignmentService $assignment) {}

    public function store(AssignJobRequest $request, Job $job): DriverLinkResource
    {
        $companyId = $request->user()->transporterCompany->id;
        $award = $this->authorizeCompanyOwnership($request, $job);

        $truck = Truck::where('transporter_company_id', $companyId)->findOrFail($request->integer('truck_id'));
        $driver = Driver::where('transporter_company_id', $companyId)->findOrFail($request->integer('driver_id'));

        $link = $this->assignment->assign($job, $truck, $driver, $award);

        return new DriverLinkResource($link->load('driver'));
    }

    /**
     * Re-fetches the job's current Driver Link so the company app can
     * display/re-share it any time — not just in the moment right after
     * assigning (AppFlow §2.5: "shows it in-app to re-share if needed").
     *
     * Bulk Cargo epic: a multi-truck job can have several simultaneously
     * active links (one per roster truck), so `truck_id` disambiguates
     * which one — omitted (or on an ordinary single-truck job), today's
     * exact "the job's one active link" lookup runs unchanged.
     *
     * Multi-Company Split Awards epic: with 2+ awarded companies on one
     * job, "the job's latest active link" is ambiguous and could return a
     * *different* company's link/token — so once the caller has an award
     * (rather than being the sole legacy-assigned company), this always
     * resolves relative to that award, never the bare job.
     */
    public function driverLink(Request $request, Job $job): DriverLinkResource
    {
        $companyId = $request->user()->transporterCompany->id;
        $award = $this->authorizeCompanyOwnership($request, $job);

        if ($award !== null) {
            $truckId = $request->filled('truck_id')
                ? $request->integer('truck_id')
                : $award->leadTruckAssignment?->truck_id;

            $assignment = JobTruckAssignment::where('job_award_id', $award->id)
                ->where('truck_id', $truckId)
                ->firstOrFail();

            return new DriverLinkResource($assignment->driverLink->load('driver'));
        }

        if ($request->filled('truck_id')) {
            // A company must own the truck it's asking about — otherwise,
            // once ownership is loosened to "any awarded company," nothing
            // would stop it from passing an arbitrary truck_id and fetching
            // a competitor's link/token.
            abort_unless(
                Truck::where('id', $request->integer('truck_id'))->where('transporter_company_id', $companyId)->exists(),
                404
            );

            $assignment = JobTruckAssignment::where('job_id', $job->id)
                ->whereNull('job_award_id')
                ->where('truck_id', $request->integer('truck_id'))
                ->firstOrFail();

            return new DriverLinkResource($assignment->driverLink->load('driver'));
        }

        $link = DriverLink::where('job_id', $job->id)->where('status', 'active')->latest()->firstOrFail();

        return new DriverLinkResource($link->load('driver'));
    }

    /**
     * A company may act on a job either because it's the sole
     * legacy-assigned company (Tier 1/2, unchanged) or because it holds
     * one of the job's awards (Multi-Company Split Awards epic) — returns
     * that award when the latter applies, so callers can scope everything
     * else (truck lookups, assignment, driver-link resolution) to it.
     */
    private function authorizeCompanyOwnership(Request $request, Job $job): ?JobAward
    {
        $companyId = $request->user()->transporterCompany->id;

        if ($job->assigned_company_id === $companyId) {
            return null;
        }

        $award = JobAward::where('job_id', $job->id)->where('transporter_company_id', $companyId)->first();
        abort_if($award === null, 404);

        return $award;
    }
}
