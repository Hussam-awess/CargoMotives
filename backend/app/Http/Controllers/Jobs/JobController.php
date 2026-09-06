<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Jobs\PostJobRequest;
use App\Http\Resources\JobResource;
use App\Models\Job;
use App\Services\Documents\DocumentStorage;
use App\Services\Geo\GeoPoint;
use App\Services\Jobs\JobPostQuotaService;
use App\Services\Quota\QuotaExceededException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
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
    ) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $query = Job::withCoordinates()
            ->where('customer_id', $request->user()->id)
            ->withCount('bids')
            ->latest();

        if ($status = $request->string('status')->toString()) {
            $query->where('status', $status);
        }

        return JobResource::collection($query->paginate(20));
    }

    public function show(Request $request, Job $job): JobResource
    {
        $this->authorizeCustomerOwnership($request, $job);

        return new JobResource(Job::withCoordinates()->findOrFail($job->id));
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

        $updated = $this->save($request, $request->user()->id, $job);

        return new JobResource(Job::withCoordinates()->findOrFail($updated->id));
    }

    public function cancel(Request $request, Job $job): JobResource
    {
        $this->authorizeCustomerOwnership($request, $job);

        if ($job->status !== 'open') {
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
            $job->fill($attributes);
        } else {
            $job = new Job($attributes);
            $job->customer_id = $customerId;
        }

        $job->setPickupLocation(new GeoPoint($validated['pickup_lat'], $validated['pickup_lng']));
        $job->setDropoffLocation(new GeoPoint($validated['dropoff_lat'], $validated['dropoff_lng']));
        $job->save();

        return $job;
    }
}
