<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Jobs\AssignJobRequest;
use App\Http\Requests\Jobs\SubmitProofOfDeliveryRequest;
use App\Http\Resources\DriverLinkResource;
use App\Http\Resources\JobResource;
use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobTruckAssignment;
use App\Models\Truck;
use App\Services\Documents\DocumentStorage;
use App\Services\Jobs\JobAssignmentService;
use App\Services\Jobs\ProofOfDeliveryService;
use App\Services\Sms\SmsGateway;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Company assigning a truck + driver to a job it has already won
 * (AppFlow §2.5) — separate from CompanyJobController (browsing/bidding)
 * since this is a distinct concern with its own authorization shape
 * (a company only ever acts on jobs assigned to *it*, never any open job).
 */
class JobAssignmentController extends Controller
{
    public function __construct(
        private readonly JobAssignmentService $assignment,
        private readonly DocumentStorage $documents,
        private readonly SmsGateway $sms,
        private readonly ProofOfDeliveryService $proofOfDelivery,
    ) {}

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
        $award = $this->authorizeCompanyOwnership($request, $job);

        return new DriverLinkResource($this->resolveDriverLink($request, $job, $award)->load('driver'));
    }

    /**
     * A one-way note from the company to whichever driver(s) are currently
     * on this job/award — the only channel that exists to reach a driver at
     * all, since they have no account and no push channel (TRD §7). Sent to
     * every currently-active Driver Link in scope (not just one, unlike
     * resolveDriverLink()'s single-target resolution) since a multi-truck
     * roster can have several drivers who all need to know at once. No
     * reply channel — see the docblock on Message (customer<->company only).
     */
    public function updateInstructions(Request $request, Job $job): JobResource
    {
        $award = $this->authorizeCompanyOwnership($request, $job);
        $request->validate(['instructions' => ['required', 'string', 'max:1000']]);
        $instructions = $request->string('instructions')->toString();

        ($award ?? $job)->update(['driver_instructions' => $instructions]);

        $linkIds = $award !== null
            ? JobTruckAssignment::where('job_award_id', $award->id)->pluck('driver_link_id')
            : DriverLink::where('job_id', $job->id)->pluck('id');

        DriverLink::whereIn('id', $linkIds)->where('status', 'active')->with('driver')->get()
            ->each(fn (DriverLink $link) => $this->sms->send(
                $link->driver->phone_number,
                "Cargo Motives: new instructions for Job #{$job->id} — {$instructions}",
            ));

        return new JobResource($job->fresh());
    }

    /**
     * A manual escape hatch for exactly the case GPS-based auto-advancement
     * can't handle: the truck has genuinely reached the drop-off but a
     * stale/inaccurate GPS fix (or an unreliable connection) never crossed
     * JobStatusAutoAdvancer's arrival radius, so the job would otherwise
     * sit at 'in_transit' forever. Lets the company submit proof of
     * delivery itself, from its own app, instead of relying on the driver
     * visiting the separate Driver Link page — the same
     * ProofOfDelivery record either path produces, so the customer/company/
     * Admin views of it are identical regardless of who submitted it.
     * Deliberately still requires an existing driver link (never fabricates
     * a driver_id): every assigned job always has one from
     * JobAssignmentService::assign(), so this never actually blocks a real
     * job — it just reuses that link's driver and marks it used, the same
     * as if the driver had submitted it themselves.
     */
    public function submitProofOfDelivery(SubmitProofOfDeliveryRequest $request, Job $job): JobResource
    {
        $award = $this->authorizeCompanyOwnership($request, $job);
        $statusHolder = $award ?? $job;

        if (! in_array($statusHolder->status, ['assigned', 'en_route_pickup', 'picked_up', 'in_transit'], true)) {
            throw ValidationException::withMessages([
                'status' => ['This job has already moved past that point.'],
            ]);
        }

        // The drop-off permit is job-level (never per-award — see the
        // permit migrations' docblocks), so this checks $job regardless of
        // whether $statusHolder is the job itself or one of its awards.
        if ($job->dropoff_permit_path === null) {
            throw ValidationException::withMessages([
                'dropoff_permit' => ['Attach the drop-off permit before this job can be marked delivered.'],
            ]);
        }

        $link = $this->resolveDriverLink($request, $job, $award);

        $photoKeys = collect($request->file('photos'))
            ->map(fn ($photo) => $this->documents->store($photo, "proof-of-delivery/{$job->id}"))
            ->all();

        $this->proofOfDelivery->submit($job, $award, $link, $photoKeys, $request->validated('recipient_name'), $request->validated('notes'));

        return new JobResource($job->fresh());
    }

    /**
     * Same lookup driverLink() and submitProofOfDelivery() both need: the
     * one active Driver Link for this job (or, Multi-Company Split Awards
     * epic, this award), optionally disambiguated by truck_id on a
     * multi-truck roster.
     */
    private function resolveDriverLink(Request $request, Job $job, ?JobAward $award): DriverLink
    {
        $companyId = $request->user()->transporterCompany->id;

        if ($award !== null) {
            $truckId = $request->filled('truck_id')
                ? $request->integer('truck_id')
                : $award->leadTruckAssignment?->truck_id;

            $assignment = JobTruckAssignment::where('job_award_id', $award->id)
                ->where('truck_id', $truckId)
                ->firstOrFail();

            return $assignment->driverLink;
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

            return $assignment->driverLink;
        }

        return DriverLink::where('job_id', $job->id)->where('status', 'active')->latest()->firstOrFail();
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
