<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Jobs\PostJobRequest;
use App\Http\Resources\DisputeResource;
use App\Http\Resources\JobResource;
use App\Models\Bid;
use App\Models\Dispute;
use App\Models\Job;
use App\Models\Truck;
use App\Models\User;
use App\Services\Documents\DocumentStorage;
use App\Services\Geo\GeoPoint;
use App\Services\Jobs\JobPostQuotaService;
use App\Services\Notifications\NotificationService;
use App\Services\Quota\QuotaExceededException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The Customer side of job posting (AppFlow §3.2). Company-side job
 * discovery (Open/My Bids/Active feeds) lives in CompanyJobController —
 * split because the two sides have almost nothing in common beyond
 * reading the same Job model.
 */
class JobController extends Controller
{
    public function __construct(
        private readonly JobPostQuotaService $postQuota,
        private readonly DocumentStorage $documents,
        private readonly NotificationService $notifications,
    ) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        // assignedCompany was missing here too (see show()'s comment) — the
        // shipment list's own assigned-company name/tap-to-profile link
        // was silently absent for the same reason. assignedDriver was the
        // same story for the Messages inbox: without it eager-loaded,
        // JobResource::assigned_driver_name's whenLoaded() omits the field
        // entirely, so a customer's own conversation list never had a
        // driver name to show at all, even for a job that has one.
        $query = Job::withCoordinates()
            ->where('customer_id', $request->user()->id)
            ->with([
                'assignedCompany', 'assignedDriver', 'awards.company', 'awards.truckAssignments.truck', 'awards.truckAssignments.driver',
                'awards.proofOfDelivery',
            ])
            ->withCount(['bids', 'jobViews'])
            ->latest();

        if ($status = $request->string('status')->toString()) {
            $query->where('status', $status);
        }

        return JobResource::collection($query->paginate(20));
    }

    public function show(Request $request, Job $job): JobResource
    {
        $this->authorizeCustomerOwnership($request, $job);

        // assignedCompany was missing here — a real, pre-existing gap: the
        // customer's own Transporter card has shown truck/driver but never
        // the assigned company's own name (JobResource.assigned_company_name
        // is whenLoaded-gated), and there was no way to open its public
        // profile either (Phase: public profiles) without this.
        return new JobResource(
            Job::withCoordinates()
                ->with([
                    'assignedTruck', 'assignedDriver', 'assignedCompany', 'proofOfDelivery', 'truckAssignments.truck', 'truckAssignments.driver',
                    'awards.company', 'awards.truckAssignments.truck', 'awards.truckAssignments.driver', 'awards.proofOfDelivery',
                ])
                ->withCount('jobViews')
                ->findOrFail($job->id)
        );
    }

    public function store(PostJobRequest $request): JobResource|JsonResponse
    {
        try {
            $this->postQuota->consume($request->user());
        } catch (QuotaExceededException $e) {
            return response()->json([
                'message' => 'You have reached your daily job-posting limit.',
                'seconds_until_slot_frees' => $e->secondsUntilSlotFrees,
            ], 429);
        }

        $job = $this->save($request, $request->user()->id, null);

        // Re-fetching through withCoordinates() (needed to populate the
        // lat/lng the resource exposes) returns a freshly-queried model
        // whose wasRecentlyCreated is false, so Laravel's automatic
        // "201 for a just-created resource" (ResourceResponse) doesn't
        // fire here the way it does for Phase 2/3's simpler create()
        // responses — set it explicitly instead of relying on that flag.
        return (new JobResource(Job::withCoordinates()->findOrFail($job->id)))
            ->response()
            ->setStatusCode(201);
    }

    public function update(PostJobRequest $request, Job $job): JobResource
    {
        $this->authorizeCustomerOwnership($request, $job);
        $this->assertEditable($job);

        // Captured before save() overwrites the PostGIS columns — the only
        // way to tell whether the pin actually moved (route model binding
        // doesn't load pickup_lat/lng; only Job::withCoordinates() does).
        $previous = Job::withCoordinates()->findOrFail($job->id);
        $updated = $this->save($request, $request->user()->id, $job);

        if ($this->locationChanged($previous, $request->validated())) {
            $this->withdrawPendingBids($updated);
        }

        return new JobResource(Job::withCoordinates()->findOrFail($updated->id));
    }

    /**
     * Rounded to 5 decimal places (~1.1m) rather than compared exactly —
     * a value that round-trips through PostGIS storage and back can pick up
     * float noise even when the customer didn't actually move the pin.
     */
    private function locationChanged(Job $previous, array $validated): bool
    {
        return round((float) $previous->pickup_lat, 5) !== round((float) $validated['pickup_lat'], 5)
            || round((float) $previous->pickup_lng, 5) !== round((float) $validated['pickup_lng'], 5)
            || round((float) $previous->dropoff_lat, 5) !== round((float) $validated['dropoff_lat'], 5)
            || round((float) $previous->dropoff_lng, 5) !== round((float) $validated['dropoff_lng'], 5);
    }

    /**
     * A pending bid was priced for a specific distance — moving the pickup
     * or drop-off point out from under it would leave a company committed
     * to a price that may no longer make sense, so editing the route
     * withdraws every pending bid instead of leaving them silently stale.
     * Never touches an already-accepted bid: assertEditable() already
     * guarantees the job is still 'open', and a job only leaves 'open' by
     * accepting one (BidController::accept()), so no bid here can be
     * anything but 'pending' or already resolved from an earlier cycle.
     */
    private function withdrawPendingBids(Job $job): void
    {
        Bid::where('job_id', $job->id)->where('status', 'pending')->with('company.owner')->get()
            ->each(function (Bid $bid) use ($job) {
                $bid->update(['status' => 'withdrawn']);

                if ($bid->company->owner !== null) {
                    $this->notifications->send(
                        $bid->company->owner,
                        'bid_withdrawn',
                        'Bid withdrawn',
                        "The pickup/drop-off location for Job #{$job->id} changed, so your bid was automatically withdrawn. You're welcome to place a new one at the updated distance.",
                        $job,
                    );
                }
            });
    }

    public function cancel(Request $request, Job $job): JobResource
    {
        $this->authorizeCustomerOwnership($request, $job);

        // Multi-Company Split Awards epic: a partially-covered bulk job
        // can have committed awards while jobs.status is still 'open' —
        // a customer can't cancel out from under a company that's already
        // started fulfilling its slice, even though the job overall
        // hasn't fully closed to bidding yet.
        if ($job->status !== 'open' || $job->awards()->exists()) {
            // PRD §8: cancellation is only allowed from 'open' — once a bid
            // is accepted, the company has committed resources to it.
            throw ValidationException::withMessages([
                'status' => ['Only an open job can be cancelled.'],
            ]);
        }

        $job->update([
            'status' => 'cancelled',
            'cancelled_reason' => $request->string('reason')->toString() ?: null,
        ]);

        return new JobResource($job);
    }

    public function postQuota(Request $request): JsonResponse
    {
        return response()->json(['remaining' => $this->postQuota->remaining($request->user())]);
    }

    /**
     * Customer confirms receipt after a driver submits proof of delivery
     * (AppFlow §3.5). "Report a Problem" (the AppFlow alternative to
     * confirming) is reportProblem() below, routing to the disputes table
     * Phase 9 added.
     */
    public function confirmDelivery(Request $request, Job $job): JobResource
    {
        $this->authorizeCustomerOwnership($request, $job);

        if ($job->status !== 'delivered') {
            throw ValidationException::withMessages([
                'status' => ['This job has no delivery awaiting confirmation.'],
            ]);
        }

        DB::transaction(function () use ($job) {
            $job->update(['status' => 'completed']);
            // completed_at is the real completion moment — distinct from
            // preferred_pickup_window_start/end (the originally requested
            // schedule) and never backdated to any of it. Set directly
            // rather than through update()'s mass assignment: it's
            // deliberately excluded from Job's #[Fillable] (system-set
            // only, same reasoning as User::password_hash), so a mass
            // assignment here would be silently discarded.
            $job->completed_at = now();
            $job->save();
            $job->proofOfDelivery()->update(['confirmed_by_customer_at' => now()]);

            if ($job->assigned_truck_id !== null) {
                Truck::whereKey($job->assigned_truck_id)->update(['current_status' => 'idle']);
            }

            // Bulk Cargo epic: the line above only frees the lead truck.
            // A multi-truck job's other roster trucks would otherwise stay
            // stuck 'on_job' forever — this additionally releases every
            // roster truck (harmless double-update on the lead, already
            // freed above).
            if ($job->isMultiTruck()) {
                Truck::whereIn('id', $job->truckAssignments()->pluck('truck_id'))->update(['current_status' => 'idle']);
            }
        });

        return new JobResource(
            Job::withCoordinates()->with(['assignedTruck', 'assignedDriver', 'proofOfDelivery'])->findOrFail($job->id)
        );
    }

    /**
     * "Report a Problem" (AppFlow §3.5) — the alternative to
     * confirmDelivery() once a driver has submitted proof of delivery.
     * Raises a Dispute for Admin to review (PRD §10 item 8) against the
     * job's proof of delivery and, when available, its GPS history; it
     * deliberately does NOT change the job's own status — a dispute is a
     * parallel review process, not a job state, and Admin's resolution
     * decides what (if anything) happens next.
     */
    public function reportProblem(Request $request, Job $job): DisputeResource
    {
        $this->authorizeCustomerOwnership($request, $job);

        if ($job->status !== 'delivered') {
            throw ValidationException::withMessages([
                'status' => ['This job has no delivery to report a problem with.'],
            ]);
        }

        if ($job->disputes()->whereIn('status', ['open', 'under_review'])->exists()) {
            throw ValidationException::withMessages([
                'job_id' => ['A dispute for this job is already under review.'],
            ]);
        }

        $request->validate(['reason' => ['required', 'string', 'min:10', 'max:1000']]);

        $dispute = Dispute::create([
            'job_id' => $job->id,
            'raised_by_user_id' => $request->user()->id,
            'reason' => $request->string('reason'),
        ]);

        return new DisputeResource($dispute);
    }

    /**
     * The pickup permit a cargo-authority checkpoint requires before
     * loading — customer-uploaded, informational only (never blocks any
     * job transition). See submitDropoffPermit()'s docblock for the
     * counterpart that DOES block.
     */
    public function submitPickupPermit(Request $request, Job $job): JobResource
    {
        $this->authorizeCustomerOwnership($request, $job);

        $request->validate(['document' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240']]);

        $path = $this->documents->store($request->file('document'), "jobs/permits/{$job->id}");
        $job->update(['pickup_permit_path' => $path, 'pickup_permit_uploaded_at' => now()]);

        return new JobResource($job->fresh());
    }

    /**
     * The drop-off permit a cargo-authority checkpoint requires before
     * unloading — customer-uploaded, and a hard blocker on
     * JobAssignmentController::submitProofOfDelivery() and
     * DriverLinkPageController::submitProofOfDelivery() alike (both check
     * $job->dropoff_permit_path directly, never a re-derived flag). No
     * status restriction on when it can be (re-)uploaded — a customer may
     * replace a mistaken upload any time; the old file is left orphaned
     * rather than deleted, matching DocumentStorage's existing no-cleanup
     * convention for every other document type in this app.
     */
    public function submitDropoffPermit(Request $request, Job $job): JobResource
    {
        $this->authorizeCustomerOwnership($request, $job);

        $request->validate(['document' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240']]);

        $path = $this->documents->store($request->file('document'), "jobs/permits/{$job->id}");
        $job->update(['dropoff_permit_path' => $path, 'dropoff_permit_uploaded_at' => now()]);

        return new JobResource($job->fresh());
    }

    private function authorizeCustomerOwnership(Request $request, Job $job): void
    {
        abort_unless($job->customer_id === $request->user()->id, 404);
    }

    private function assertEditable(Job $job): void
    {
        if ($job->status !== 'open') {
            throw ValidationException::withMessages([
                'status' => ['A job can only be edited while still open — once bidding has started, changing it would be unfair to bidders.'],
            ]);
        }
    }

    private function save(PostJobRequest $request, int $customerId, ?Job $job): Job
    {
        $validated = $request->validated();

        $photoKeys = collect($request->file('photos', []))
            ->map(fn ($photo) => $this->documents->store($photo, 'jobs/photos'))
            ->all();

        $attributes = collect($validated)->except([
            'pickup_lat', 'pickup_lng', 'dropoff_lat', 'dropoff_lng', 'photos',
        ])->all();
        $attributes['photo_urls'] = $photoKeys ?: null;

        if ($job) {
            // Currency is set once, at creation, and never changes after —
            // a bid already placed on this job is denominated in whatever
            // currency it was posted in, so editing it out from under an
            // existing bid would silently mismatch the two.
            unset($attributes['currency']);
            $job->fill($attributes);
        } else {
            // 'currency' is a 'sometimes' rule (PostJobRequest) — an older
            // client that predates it, or simply omits it, falls back to
            // the posting customer's own preferred_currency rather than
            // silently becoming Job's blanket 'TZS' default regardless of
            // what this customer actually chose in Settings.
            if (! array_key_exists('currency', $attributes)) {
                $attributes['currency'] = User::find($customerId)?->preferred_currency ?? 'TZS';
            }
            $job = new Job($attributes);
            $job->customer_id = $customerId;
        }

        $job->setPickupLocation(new GeoPoint($validated['pickup_lat'], $validated['pickup_lng']));
        $job->setDropoffLocation(new GeoPoint($validated['dropoff_lat'], $validated['dropoff_lng']));
        $job->save();

        return $job;
    }
}
