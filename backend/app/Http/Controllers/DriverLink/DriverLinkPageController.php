<?php

namespace App\Http\Controllers\DriverLink;

use App\Http\Controllers\Controller;
use App\Http\Requests\DriverLink\SubmitProofOfDeliveryRequest;
use App\Http\Requests\DriverLink\UpdateJobStatusRequest;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobTruckAssignment;
use App\Models\ProofOfDelivery;
use App\Services\Documents\DocumentStorage;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\DB;

/**
 * The Driver Link (AppFlow §4, TRD's "Lightweight server-rendered mobile
 * web page — no login, no app install"). Deliberately plain Blade + a web
 * session (for CSRF only) rather than a Flutter/JSON screen: a driver has
 * no account and may be on a very basic phone browser, so this has to work
 * without an app install or any client-side framework.
 *
 * Every action here is authorized by the token alone (App\Models\DriverLink)
 * — there is no Sanctum guard, no logged-in user, by design (TRD §7).
 */
class DriverLinkPageController extends Controller
{
    /**
     * Job statuses a driver may move a job through via this page, in
     * order. "delivered" is reached only by submitting proof of delivery,
     * never by a plain status update — see submitProofOfDelivery().
     */
    private const DRIVER_SETTABLE_STATUSES = ['en_route_pickup', 'picked_up', 'in_transit'];

    public function __construct(private readonly DocumentStorage $documents) {}

    public function show(string $token): View
    {
        $link = DriverLink::where('token', $token)->with(['job', 'driver', 'proofOfDelivery'])->first();

        if ($link === null) {
            return view('driver-link.not-found');
        }

        if ($link->status === 'used') {
            return view('driver-link.submitted', ['proofOfDelivery' => $link->proofOfDelivery]);
        }

        if (! $link->isValid()) {
            return view('driver-link.expired');
        }

        $job = $link->job;
        $award = $this->resolveAward($link);
        $statusForDriver = $award?->status ?? $job->status;
        $nextStatus = $this->nextDriverSettableStatus($statusForDriver);
        $mayControlStatus = $this->mayControlStatus($job, $link);

        return view('driver-link.show', [
            'job' => $job,
            'token' => $token,
            'nextStatus' => $nextStatus,
            'canSubmitProofOfDelivery' => $mayControlStatus && in_array($statusForDriver, ['assigned', ...self::DRIVER_SETTABLE_STATUSES], true),
            // Bulk Cargo epic: a non-lead roster member on a multi-truck
            // job can view their assignment (pickup/dropoff, their own
            // link) but never advance the job's (or, Multi-Company Split
            // Awards epic, their award's own) shared status — see
            // mayControlStatus().
            'mayControlStatus' => $mayControlStatus,
        ]);
    }

    public function updateStatus(UpdateJobStatusRequest $request, string $token): RedirectResponse
    {
        $link = $this->resolveActiveOrAbort($token);
        $job = $link->job;
        $award = $this->resolveAward($link);

        abort_unless($this->mayControlStatus($job, $link), 403, 'Only the lead truck can update this job\'s status.');

        $statusForDriver = $award?->status ?? $job->status;
        $order = array_flip(['open', 'assigned', ...self::DRIVER_SETTABLE_STATUSES, 'delivered', 'completed', 'cancelled']);
        $requested = $request->validated('status');

        if (($order[$requested] ?? -1) <= ($order[$statusForDriver] ?? PHP_INT_MAX)) {
            return back()->withErrors(['status' => 'This job has already moved past that point.']);
        }

        // Multi-Company Split Awards epic: an award reaching 'delivered'
        // never touches jobs.status — the job only ever reflects 'assigned'
        // or 'completed' once EVERY award is done (JobAwardController).
        ($award ?? $job)->update(['status' => $requested]);

        return back()->with('success', 'Status updated.');
    }

    public function submitProofOfDelivery(SubmitProofOfDeliveryRequest $request, string $token): RedirectResponse
    {
        $link = $this->resolveActiveOrAbort($token);
        $job = $link->job;
        $award = $this->resolveAward($link);

        abort_unless($this->mayControlStatus($job, $link), 403, 'Only the lead truck can submit proof of delivery.');

        $statusForDriver = $award?->status ?? $job->status;
        if ($statusForDriver === 'delivered' || $statusForDriver === 'completed') {
            return back()->withErrors(['photos' => 'Proof of delivery was already submitted for this job.']);
        }

        $photoKeys = collect($request->file('photos'))
            ->map(fn ($photo) => $this->documents->store($photo, "proof-of-delivery/{$job->id}"))
            ->all();

        DB::transaction(function () use ($request, $job, $award, $link, $photoKeys) {
            ProofOfDelivery::create([
                'job_id' => $job->id,
                'job_award_id' => $award?->id,
                'driver_id' => $link->driver_id,
                'driver_link_id' => $link->id,
                'photo_urls' => $photoKeys,
                'recipient_name' => $request->validated('recipient_name'),
                'notes' => $request->validated('notes'),
            ]);

            ($award ?? $job)->update(['status' => 'delivered']);
            $link->update(['status' => 'used', 'used_at' => now()]);

            // "Fans out instantly to the Customer, the Company, and Admin's
            // record" (AppFlow §4) — satisfied by the data itself becoming
            // visible on the next fetch of the job (JobResource now exposes
            // proof_of_delivery) for whichever of the three looks at it,
            // the same ordinary REST + refresh-on-open pattern already used
            // for messaging/status lists (TRD §4) rather than a new push
            // channel. No FCM/notifications infrastructure exists yet in
            // this codebase (nor has any prior phase built one, despite the
            // notification trigger map listing "Push" for earlier events
            // too) — that's a bigger, separate piece of work, not something
            // to half-build here.
        });

        return redirect()->route('driver-link.show', $token);
    }

    /**
     * Multi-Company Split Awards epic: resolves which award (if any) this
     * driver link's roster row belongs to — null for an ordinary job and
     * for a bulk job fully covered by a single company (both keep reading/
     * writing job.status directly, exactly as before this epic).
     */
    private function resolveAward(DriverLink $link): ?JobAward
    {
        $assignment = JobTruckAssignment::where('driver_link_id', $link->id)->first();

        return $assignment?->job_award_id !== null ? $assignment->jobAward : null;
    }

    /**
     * Bulk Cargo epic: an ordinary job (trucks_needed <= 1) structurally
     * only ever has one active DriverLink, so it can always control its
     * own status — no lookup needed, matching pre-epic behavior exactly.
     * A multi-truck job's roster members can each view their own link, but
     * only the lead (JobTruckAssignment.is_lead) may advance the shared
     * status/PoD — of the job (Bulk Cargo epic) or of their own award
     * (Multi-Company Split Awards epic); either way this is the same
     * is_lead flag on the link's own roster row, so no change is needed
     * here to support awards.
     */
    private function mayControlStatus(Job $job, DriverLink $link): bool
    {
        if ($job->trucks_needed <= 1) {
            return true;
        }

        return JobTruckAssignment::where('driver_link_id', $link->id)->value('is_lead') === true;
    }

    private function resolveActiveOrAbort(string $token): DriverLink
    {
        $link = DriverLink::where('token', $token)->with('job')->first();

        abort_if($link === null, 404);
        abort_unless($link->isValid(), 410, 'This link has expired.');

        return $link;
    }

    private function nextDriverSettableStatus(string $currentStatus): ?string
    {
        // 'assigned' isn't itself in DRIVER_SETTABLE_STATUSES (it's the
        // status a job starts this page in), so it maps to "start of the
        // list" rather than array_search's `false` — done explicitly here
        // rather than relying on false's arithmetic behavior (`false + 1`
        // coerces to 1, which would wrongly skip straight to "picked_up").
        if ($currentStatus === 'assigned') {
            return self::DRIVER_SETTABLE_STATUSES[0];
        }

        $index = array_search($currentStatus, self::DRIVER_SETTABLE_STATUSES, true);

        return $index === false ? null : (self::DRIVER_SETTABLE_STATUSES[$index + 1] ?? null);
    }
}
