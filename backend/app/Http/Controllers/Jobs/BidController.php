<?php

namespace App\Http\Controllers\Jobs;

use App\Events\BidPlaced;
use App\Http\Controllers\Controller;
use App\Http\Requests\Jobs\PlaceBidRequest;
use App\Http\Resources\BidResource;
use App\Http\Resources\JobResource;
use App\Models\Bid;
use App\Models\Job;
use App\Models\JobAward;
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
        $trucksOffered = (int) $request->validated('trucks_offered');
        $quotaExceeded = null;

        $bid = DB::transaction(function () use ($request, $job, $company, $trucksOffered, &$quotaExceeded) {
            // Row-locked so two companies' bids can't both claim more of a
            // bulk job's remaining capacity than actually exists (Multi-
            // Company Split Awards epic) — the same lock accept() takes.
            $job = Job::whereKey($job->id)->lockForUpdate()->firstOrFail();

            if ($job->status !== 'open') {
                throw ValidationException::withMessages(['status' => ['This job is no longer open for bidding.']]);
            }

            // Bidding Deadline epic: a second, independent condition on top
            // of the status check above — composes for free with the
            // Multi-Company Split Awards epic's own "stays open until fully
            // covered" behavior, since both just check job.status === 'open'
            // before this.
            if ($job->isBiddingClosed()) {
                throw ValidationException::withMessages(['bidding_expires_at' => ['Bidding has closed for this job.']]);
            }

            if (Bid::where('job_id', $job->id)->where('transporter_company_id', $company->id)->where('status', 'pending')->exists()) {
                throw ValidationException::withMessages(['job_id' => ['You already have a pending bid on this job.']]);
            }

            if (JobAward::where('job_id', $job->id)->where('transporter_company_id', $company->id)->exists()) {
                throw ValidationException::withMessages(['job_id' => ['You already have an awarded portion of this job.']]);
            }

            $remaining = $job->trucks_needed - JobAward::where('job_id', $job->id)->sum('trucks_offered');
            if ($trucksOffered > $remaining) {
                throw ValidationException::withMessages([
                    'trucks_offered' => ["Only {$remaining} truck(s) of capacity remain on this job."],
                ]);
            }

            // Bulk Cargo epic, corrected by the Multi-Company Split Awards
            // epic: a company only needs enough verified trucks for what
            // it's actually offering, not the job's full requirement —
            // this is exactly what lets a small fleet bid on a big job.
            if ($company->verifiedTruckCount() < $trucksOffered) {
                throw ValidationException::withMessages([
                    'company_id' => ["Your verified fleet ({$company->verifiedTruckCount()} trucks) is smaller than the {$trucksOffered} trucks you're offering."],
                ]);
            }

            // Quota is consumed last, only once every other check has
            // passed — consuming it earlier and then hitting a validation
            // error would burn a company's bidding quota on a bid that
            // never actually got placed (the Redis-backed quota isn't part
            // of this DB transaction, so it wouldn't roll back either).
            try {
                $this->quota->consume($company);
            } catch (QuotaExceededException $e) {
                $quotaExceeded = $e;

                return null;
            }

            return Bid::create([
                ...$request->validated(),
                'job_id' => $job->id,
                'transporter_company_id' => $company->id,
                'is_priority' => $company->is_featured,
            ]);
        });

        if ($quotaExceeded !== null) {
            return response()->json([
                'message' => 'You have reached your bidding limit.',
                'seconds_until_slot_frees' => $quotaExceeded->secondsUntilSlotFrees,
            ], 429);
        }

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
     * Accepting a bid is one transaction (TRD §6): assign the job (or add
     * to it — Multi-Company Split Awards epic), copy the price, and close
     * every other pending bid ONLY once the job's full trucks_needed is
     * actually covered. Row-level locking on the job guards against two
     * accept requests racing (e.g. a slow client retry, or two different
     * bids for the same remaining capacity) into a double-assignment.
     *
     * Two outcomes, branched on cumulative coverage so far:
     *  - No award exists yet AND this bid alone covers everything still
     *    needed: today's exact single-company behavior, byte-for-byte —
     *    no job_awards row is ever created for this, the overwhelming
     *    majority, case.
     *  - Otherwise (this bid is partial, or a prior award already exists):
     *    a new job_awards row for this company, leaving the job's legacy
     *    scalar assigned_* fields untouched (there's no single "the"
     *    company once 2+ are involved). The job only closes to further
     *    bidding once cumulative awarded trucks reach trucks_needed.
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

            $alreadyAwarded = JobAward::where('job_id', $job->id)->sum('trucks_offered');
            $remaining = $job->trucks_needed - $alreadyAwarded;

            if ($bid->trucks_offered > $remaining) {
                throw ValidationException::withMessages([
                    'trucks_offered' => ["This bid offers more trucks than the job still needs ({$remaining} remaining)."],
                ]);
            }

            if ($alreadyAwarded === 0 && $bid->trucks_offered >= $remaining) {
                $job->update([
                    'status' => 'assigned',
                    'assigned_company_id' => $bid->transporter_company_id,
                    'assigned_bid_id' => $bid->id,
                    'agreed_price' => $bid->price,
                ]);
            } else {
                JobAward::create([
                    'job_id' => $job->id,
                    'bid_id' => $bid->id,
                    'transporter_company_id' => $bid->transporter_company_id,
                    'trucks_offered' => $bid->trucks_offered,
                    'agreed_price' => $bid->price,
                ]);

                if ($alreadyAwarded + $bid->trucks_offered >= $job->trucks_needed) {
                    $job->update(['status' => 'assigned']);
                }
                // else: job stays 'open' — other companies can still bid
                // on whatever capacity remains, and any of their pending
                // bids are left alone rather than rejected below.
            }

            $bid->update(['status' => 'accepted']);

            if ($job->fresh()->status !== 'open') {
                // Individually, not a bulk ->update(): a bulk query-builder
                // update never fires Eloquent model events, and
                // BidObserver::updated() firing the "bid not selected"
                // notification (Phase 12) to each losing company depends on
                // wasChanged('status') actually running per row. Competing
                // pending bids on one job are a small set, so this is cheap.
                Bid::where('job_id', $job->id)
                    ->where('id', '!=', $bid->id)
                    ->where('status', 'pending')
                    ->with('company.owner')
                    ->get()
                    ->each(fn (Bid $losingBid) => $losingBid->update(['status' => 'rejected']));
            }

            return response()->json([
                'job' => (new JobResource(
                    Job::withCoordinates()
                        ->with(['assignedTruck', 'assignedDriver', 'assignedCompany', 'awards.company', 'awards.truckAssignments.truck', 'awards.truckAssignments.driver', 'awards.proofOfDelivery'])
                        ->findOrFail($job->id)
                ))->resolve(),
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
