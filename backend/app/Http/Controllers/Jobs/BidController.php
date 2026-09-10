<?php

namespace App\Http\Controllers\Jobs;

use App\Events\BidPlaced;
use App\Http\Controllers\Controller;
use App\Http\Requests\Jobs\PlaceBidRequest;
use App\Http\Resources\BidResource;
use App\Http\Resources\JobResource;
use App\Models\Bid;
use App\Models\Job;
use App\Services\Bidding\BidQuotaService;
use App\Services\Quota\QuotaExceededException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Bidding (PRD §7.4, TRD §6): placing a bid (Company), withdrawing one
 * (Company), listing a job's bids (Customer sees all with trust profiles;
 * Company sees only its own — competitors' prices are never exposed to
 * each other), and accepting one (Customer).
 */
class BidController extends Controller
{
    public function __construct(private readonly BidQuotaService $quota) {}

    /**
     * A job's bids — Customer-only (AppFlow §3.3's "Job Detail (Open) —
     * Bids" screen). A company never sees a competitor's bid; it tracks
     * its own via the "My Bids" feed (CompanyJobController::myBids), not
     * a bids-of-a-job listing.
     */
    public function index(Request $request, Job $job): AnonymousResourceCollection
    {
        abort_unless($job->customer_id === $request->user()->id, 404);

        // Featured bids pinned first (PRD §7.4), then newest.
        $bids = Bid::with('company.trucks')
            ->where('job_id', $job->id)
            ->orderByDesc('is_priority')
            ->latest()
            ->get();

        return BidResource::collection($bids);
    }

    public function store(PlaceBidRequest $request, Job $job): BidResource|JsonResponse
    {
        $company = $request->user()->transporterCompany;

        if ($job->status !== 'open') {
            throw ValidationException::withMessages(['status' => ['This job is no longer open for bidding.']]);
        }

        if (Bid::where('job_id', $job->id)->where('transporter_company_id', $company->id)->where('status', 'pending')->exists()) {
            throw ValidationException::withMessages(['job_id' => ['You already have a pending bid on this job.']]);
        }

        try {
            $this->quota->consume($company);
        } catch (QuotaExceededException $e) {
            return response()->json([
                'message' => 'You have reached your bidding limit.',
                'seconds_until_slot_frees' => $e->secondsUntilSlotFrees,
            ], 429);
        }

        $bid = Bid::create([
            ...$request->validated(),
            'job_id' => $job->id,
            'transporter_company_id' => $company->id,
            'is_priority' => $company->is_featured,
        ]);
        $bid->load('company.trucks');

        broadcast(new BidPlaced($bid))->toOthers();

        return new BidResource($bid);
    }

    public function withdraw(Request $request, Bid $bid): BidResource
    {
        abort_unless($bid->transporter_company_id === $request->user()->transporterCompany->id, 404);

        if ($bid->status !== 'pending') {
            throw ValidationException::withMessages(['status' => ['Only a pending bid can be withdrawn.']]);
        }

        $bid->update(['status' => 'withdrawn']);

        return new BidResource($bid->load('company.trucks'));
    }

    /**
     * Accepting a bid is one transaction (TRD §6): assign the job, copy
     * the price, close every other pending bid. Row-level locking on the
     * job guards against two accept requests racing (e.g. a slow client
     * retry) into a double-assignment.
     */
    public function accept(Request $request, Bid $bid): JsonResponse
    {
        return DB::transaction(function () use ($request, $bid) {
            $job = Job::whereKey($bid->job_id)->lockForUpdate()->firstOrFail();

            abort_unless($job->customer_id === $request->user()->id, 404);

            if ($job->status !== 'open') {
                throw ValidationException::withMessages(['status' => ['This job is no longer open.']]);
            }

            if ($bid->status !== 'pending') {
                throw ValidationException::withMessages(['status' => ['This bid is no longer available.']]);
            }

            $job->update([
                'status' => 'assigned',
                'assigned_company_id' => $bid->transporter_company_id,
                'assigned_bid_id' => $bid->id,
                'agreed_price' => $bid->price,
            ]);

            $bid->update(['status' => 'accepted']);

            // Individually, not a bulk ->update(): a bulk query-builder
            // update never fires Eloquent model events, and
            // BidObserver::updated() firing the "bid not selected"
            // notification (Phase 12) to each losing company depends on
            // wasChanged('status') actually running per row. Competing
            // pending bids on one job are a small set, so this is cheap.
            Bid::where('job_id', $job->id)
                ->where('id', '!=', $bid->id)
                ->where('status', 'pending')
                ->get()
                ->each(fn (Bid $losingBid) => $losingBid->update(['status' => 'rejected']));

            return response()->json([
                'job' => (new JobResource(Job::withCoordinates()->findOrFail($job->id)))->resolve(),
                'bid' => (new BidResource($bid->fresh('company.trucks')))->resolve(),
            ]);
        });
    }

    public function quota(Request $request): JsonResponse
    {
        $company = $request->user()->transporterCompany;

        return response()->json(['remaining' => $this->quota->remaining($company)]);
    }
}
