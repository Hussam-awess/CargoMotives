<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Resources\BidResource;
use App\Http\Resources\JobResource;
use App\Models\Bid;
use App\Models\CustomerFollow;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobView;
use App\Models\TransporterCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The Company side of job discovery — the three tabs of the Jobs home
 * screen (UI/UX Brief §3): Open (the bidding feed), My Bids, Active.
 * Deliberately separate from JobController (Customer's own job list):
 * a company never sees another company's bids or a job it has no
 * relationship to beyond it being open.
 */
class CompanyJobController extends Controller
{
    /**
     * How many trucks a job still needs, after subtracting every
     * multi-company award already made against it (Multi-Company Split
     * Awards epic) — a job with no awards at all has its full
     * trucks_needed remaining, matching Bulk Cargo epic behavior exactly.
     */
    private const REMAINING_TRUCKS_SQL = 'jobs.trucks_needed - COALESCE((SELECT SUM(trucks_offered) FROM job_awards WHERE job_awards.job_id = jobs.id), 0)';

    /**
     * The open-jobs feed — any approved company can see and bid on any
     * open job (PRD §7.4: "any verified company can bid on any open job").
     * Featured companies may additionally filter to just their saved
     * preferred routes (AppFlow §2.7) via ?use_preferred_routes=1 — a
     * plain address-text match (origin/destination against pickup/
     * dropoff_address), not a geo query, since preferred_routes stores
     * free-text route descriptions, not coordinates. Ignored entirely for
     * a non-Featured company or one with no saved routes, rather than
     * erroring — this is a convenience filter, not a permission.
     *
     * Phase 10.19 adds two Plus benefits to this same feed: (1) "early
     * visibility" — a non-Featured *viewing* company only sees a job once
     * it's at least 2 minutes old, giving Featured companies a real head
     * start, not a fabricated one; (2) "priority job visibility" — a
     * Featured *customer's* own jobs sort above everyone else's. Both are
     * query-level, not post-filtered, so pagination stays correct.
     */
    public function open(Request $request): AnonymousResourceCollection
    {
        $company = $request->user()->transporterCompany;
        $verifiedTruckCount = $company->verifiedTruckCount();

        $query = Job::withCoordinates()
            ->join('users', 'jobs.customer_id', '=', 'users.id')
            ->where('jobs.status', 'open')
            // Bidding Deadline epic: "no longer visible as an available
            // bidding opportunity" once its deadline passes — a company
            // that already bid, or the customer themselves, can still see/
            // act on it elsewhere (myBids()/show() are unaffected).
            ->where(fn ($q) => $q->whereNull('jobs.bidding_expires_at')->orWhere('jobs.bidding_expires_at', '>', now()))
            ->with('customer')
            ->withCount(['bids', 'truckAssignments as assigned_trucks_count' => fn ($q) => $q->whereNull('job_award_id')])
            ->addSelect([
                'customer_completed_jobs_count' => Job::selectRaw('count(*)')
                    ->whereColumn('customer_id', 'jobs.customer_id')
                    ->where('status', 'completed'),
                'is_following_customer' => $this->isFollowingCustomerSelect($company->id),
            ])
            // Bulk Cargo epic, corrected by the Multi-Company Split Awards
            // epic: the job stays visible even when this company can't
            // cover it — demand shouldn't be hidden. is_eligible now means
            // "has at least one verified truck AND some capacity remains"
            // (a company can bid for anywhere from 1 up to what's left),
            // not "can single-handedly cover the whole job." The real,
            // enforced gate is BidController::store().
            ->selectRaw('('.self::REMAINING_TRUCKS_SQL.') as remaining_trucks_needed')
            ->selectRaw('(? > 0 AND ('.self::REMAINING_TRUCKS_SQL.') > 0) as is_eligible', [$verifiedTruckCount]);

        if (! $company->is_featured) {
            $query->where('jobs.created_at', '<=', now()->subMinutes(2));
        }

        $query->orderByDesc('users.is_featured')->orderByDesc('jobs.created_at');

        if ($request->boolean('use_preferred_routes')) {
            $this->applyPreferredRoutesFilter($query, $company);
        }

        return JobResource::collection($query->paginate(20));
    }

    /**
     * Jobs this company has placed a bid on, regardless of that bid's
     * outcome — lets a company track a bid it's still waiting on, or see
     * one it lost.
     */
    public function myBids(Request $request): AnonymousResourceCollection
    {
        $companyId = $request->user()->transporterCompany->id;

        $query = Job::withCoordinates()
            ->whereHas('bids', fn ($q) => $q->where('transporter_company_id', $companyId))
            ->with('customer')
            ->withCount(['bids', 'truckAssignments as assigned_trucks_count' => fn ($q) => $q->whereNull('job_award_id')])
            ->addSelect(['is_following_customer' => $this->isFollowingCustomerSelect($companyId)])
            ->latest();

        return JobResource::collection($query->paginate(20));
    }

    /**
     * Jobs actually assigned to this company — ongoing work, not just a
     * bid still pending review. Includes a job where this company only won
     * part of it (Multi-Company Split Awards epic) — the legacy
     * assigned_company_id column stays null for those, so an award match
     * is checked too.
     */
    public function active(Request $request): AnonymousResourceCollection
    {
        $companyId = $request->user()->transporterCompany->id;

        $query = Job::withCoordinates()
            ->where(fn ($q) => $q->where('assigned_company_id', $companyId)
                ->orWhereHas('awards', fn ($q2) => $q2->where('transporter_company_id', $companyId)))
            ->whereNotIn('status', ['cancelled'])
            ->with('customer')
            ->withCount(['bids', 'truckAssignments as assigned_trucks_count' => fn ($q) => $q->whereNull('job_award_id')])
            ->addSelect(['is_following_customer' => $this->isFollowingCustomerSelect($companyId)])
            ->latest();

        return JobResource::collection($query->paginate(20));
    }

    /**
     * A single job's detail (AppFlow §2.4: "Tap a job -> details -> Place
     * Bid"). Visible to a company only if it's open (anyone can view an
     * open job to decide whether to bid), or the company already has some
     * relationship to it (assigned, or has bid on it) — never an arbitrary
     * non-open job belonging to someone else.
     */
    public function show(Request $request, Job $job): JobResource
    {
        $company = $request->user()->transporterCompany;
        $companyId = $company->id;

        $hasAward = JobAward::where('job_id', $job->id)->where('transporter_company_id', $companyId)->exists();

        $visible = $job->status === 'open'
            || $job->assigned_company_id === $companyId
            || $hasAward
            || $job->bids()->where('transporter_company_id', $companyId)->exists();

        abort_unless($visible, 404);

        // Cargo Motives Plus benefit: record that this company opened the
        // job, so a Plus customer can see how many transporters are
        // interested (JobResource::job_views_count, computed from this on
        // the customer's own queries). firstOrCreate + the table's unique
        // index means a company re-opening the same job repeatedly only
        // ever counts once — this is "how many transporters are
        // interested," not a page-load counter.
        JobView::firstOrCreate(['job_id' => $job->id, 'transporter_company_id' => $companyId]);

        // A company can legitimately view a job it lost the bid on (via
        // "My Bids") even after it's moved past 'open' — but only the
        // *assigned* company (or an awarded one, Multi-Company Split
        // Awards epic) may see truck/driver-assignment actions on it, so
        // the app needs to tell those cases apart.
        return (new JobResource(
            Job::withCoordinates()->withCount(['bids', 'truckAssignments as assigned_trucks_count' => fn ($q) => $q->whereNull('job_award_id')])
                ->with([
                    'assignedTruck', 'assignedDriver', 'proofOfDelivery', 'customer', 'truckAssignments.truck', 'truckAssignments.driver',
                    // Constrained to the viewer's own award only — a
                    // company must never see another company's price/
                    // roster on the same job, same rule bids already have.
                    'awards' => fn ($q) => $q->where('transporter_company_id', $companyId),
                    'awards.company', 'awards.truckAssignments.truck', 'awards.truckAssignments.driver', 'awards.proofOfDelivery',
                ])
                ->addSelect(['is_following_customer' => $this->isFollowingCustomerSelect($companyId)])
                ->selectRaw('('.self::REMAINING_TRUCKS_SQL.') as remaining_trucks_needed')
                ->selectRaw('(? > 0 AND ('.self::REMAINING_TRUCKS_SQL.') > 0) as is_eligible', [$company->verifiedTruckCount()])
                ->findOrFail($job->id)
            // Deliberately NOT including $hasAward here: is_assigned_to_viewer
            // means "the one legacy-assigned company" (Tier 1/2 only) — a
            // Tier 3 company's own state comes from its award inside the
            // `awards` array instead, so the mobile app doesn't mistakenly
            // render the single-company assignment UI with null job-level
            // fields for an awarded-but-not-legacy-assigned company.
        ))->additional(['is_assigned_to_viewer' => $job->assigned_company_id === $companyId]);
    }

    /**
     * "Find a return load" (AppFlow §2.7) — Featured-only, shown right
     * after a delivery: other open jobs whose pickup point is near where
     * this job just dropped off, a real PostGIS proximity query (unlike
     * the preferred-routes filter above, which is plain address text —
     * here the docs explicitly call for a geo query, and dropoff/pickup
     * are real geography columns).
     *
     * Every nearby open job is still suggested here regardless of whether
     * it has a stated budget_price (unchanged from before claimReturnLoad()
     * existed) — the client decides per-suggestion whether to offer the
     * one-tap "Claim" action (only possible when there's a stated price to
     * claim at) or just a tap-through to bid normally.
     *
     * When the company has a home_region set, jobs whose dropoff address
     * mentions it are sorted first — a plain text match (home_region is a
     * free-text field, not coordinates), same convention as the preferred-
     * routes filter above. This is a ranking preference, not a hard
     * filter: a company with no home_region set, or one with a region set
     * but no match nearby, still sees every proximity match, just in
     * plain nearest-first order — matching a return load is strictly
     * better than showing nothing.
     */
    public function returnLoadSuggestions(Request $request, Job $job): AnonymousResourceCollection
    {
        $company = $request->user()->transporterCompany;
        abort_unless($company->is_featured, 403, 'Return-load suggestions are a Featured-only feature.');
        abort_unless($job->assigned_company_id === $company->id, 404);
        abort_unless(in_array($job->status, ['delivered', 'completed'], true), 422);

        $suggestions = $this->returnLoadCandidates($job, $company)
            ->withCount('bids')
            ->get();

        return JobResource::collection($suggestions);
    }

    /**
     * The "Return Loads" tab (Plus Polish Batch, Phase 4) — a persistent,
     * browsable version of returnLoadSuggestions() above. That endpoint
     * is anchored on one specific just-delivered job (shown right after a
     * delivery); this one has no single job to anchor on, so it anchors
     * on the union of every dropoff point across this company's own
     * jobs that are either still in progress (including a Multi-Company
     * Split Awards job this company holds an award on, which can still
     * be jobs.status = 'open' while that award itself is underway) or
     * were completed recently — old completions are excluded so this
     * list doesn't keep matching against a delivery from months ago.
     */
    public function returnLoads(Request $request): AnonymousResourceCollection
    {
        $company = $request->user()->transporterCompany;
        abort_unless($company->is_featured, 403, 'Return Loads is a Featured-only feature.');

        $anchorJobIds = Job::query()
            ->where(fn ($q) => $q->where('assigned_company_id', $company->id)
                ->orWhereHas('awards', fn ($q2) => $q2->where('transporter_company_id', $company->id)))
            ->where(fn ($q) => $q->whereNotIn('status', ['completed', 'cancelled'])
                ->orWhere(fn ($q2) => $q2->where('status', 'completed')->where('completed_at', '>=', now()->subDays(30))))
            ->pluck('id');

        if ($anchorJobIds->isEmpty()) {
            return JobResource::collection(Job::query()->whereRaw('1 = 0')->paginate(20));
        }

        $candidates = $this->nearbyOpenJobsQuery($anchorJobIds->all(), $company)->withCount('bids');

        return JobResource::collection($candidates->paginate(20));
    }

    /**
     * A Featured company's one-tap claim on a matched return load (see
     * returnLoadSuggestions() above) — "doesn't need to be bid": no price
     * negotiation, the company claims it at the job's own stated
     * budget_price. The customer still explicitly confirms it, exactly
     * like any other bid (BidController::accept() is entirely unchanged),
     * so this only skips the *competitive pricing* step, never the
     * customer's final say.
     *
     * `from_job_id` (the just-delivered job the suggestion was shown
     * against) is required and re-verified server-side — never trust the
     * client's word that $job is actually a legitimate match for it.
     */
    public function claimReturnLoad(Request $request, Job $job): JsonResponse
    {
        $company = $request->user()->transporterCompany;
        abort_unless($company->is_featured, 403, 'Return-load claims are a Featured-only feature.');

        $request->validate(['from_job_id' => ['required', 'integer']]);
        $fromJob = Job::findOrFail($request->integer('from_job_id'));

        abort_unless($fromJob->assigned_company_id === $company->id, 404);
        abort_unless(in_array($fromJob->status, ['delivered', 'completed'], true), 422);

        $isMatch = $this->returnLoadCandidates($fromJob, $company)->where('jobs.id', $job->id)->exists();
        abort_unless($isMatch, 422, 'This job is not a valid return-load match.');

        $bid = DB::transaction(function () use ($job, $company) {
            $job = Job::whereKey($job->id)->lockForUpdate()->firstOrFail();

            if ($job->status !== 'open') {
                throw ValidationException::withMessages(['status' => ['This job is no longer open.']]);
            }

            if ($job->budget_price === null) {
                throw ValidationException::withMessages(['job_id' => ['This job has no stated price to claim at — place a normal bid instead.']]);
            }

            if (Bid::where('job_id', $job->id)->where('transporter_company_id', $company->id)->where('status', 'pending')->exists()) {
                throw ValidationException::withMessages(['job_id' => ['You already have a pending bid on this job.']]);
            }

            $remaining = $job->trucks_needed - JobAward::where('job_id', $job->id)->sum('trucks_offered');

            if ($company->verifiedTruckCount() < $remaining) {
                throw ValidationException::withMessages([
                    'company_id' => ["Your verified fleet ({$company->verifiedTruckCount()} trucks) is smaller than the {$remaining} trucks this job still needs."],
                ]);
            }

            return Bid::create([
                'job_id' => $job->id,
                'transporter_company_id' => $company->id,
                'price' => $job->budget_price,
                'trucks_offered' => $remaining,
                'is_priority' => $company->is_featured,
                'is_return_load_claim' => true,
            ]);
        });

        return response()->json(['data' => (new BidResource($bid->load('company.trucks')))->resolve()]);
    }

    /**
     * The shared match query behind returnLoadSuggestions(),
     * claimReturnLoad(), and returnLoads() below — kept as one place so a
     * job can never be claimed that wasn't actually offered as a
     * suggestion first, and so the Return Loads tab's own matching logic
     * can never drift from the single-job suggestion flow's.
     *
     * Takes a *set* of anchor job ids (each one's dropoff point is a
     * candidate's must-be-nearby target) rather than a single job, so the
     * persistent Return Loads list can match against every one of a
     * company's own relevant jobs at once, not just one just-delivered
     * job.
     */
    private function nearbyOpenJobsQuery(array $anchorJobIds, TransporterCompany $company): Builder
    {
        // 50km — a reasonable "nearby" radius for a return load; no
        // specific number exists in the docs, and this isn't exposed as a
        // platform_setting since nothing else needs it configurable yet.
        $radiusMeters = 50000;
        $homeRegion = $company->home_region;

        $query = Job::withCoordinates()
            ->where('status', 'open')
            ->whereNotIn('id', $anchorJobIds)
            ->where(function (Builder $q) use ($anchorJobIds, $radiusMeters) {
                foreach ($anchorJobIds as $anchorJobId) {
                    $q->orWhereRaw(
                        'ST_DWithin(pickup_location, (SELECT dropoff_location FROM jobs WHERE id = ?), ?)',
                        [$anchorJobId, $radiusMeters],
                    );
                }
            });

        if ($homeRegion) {
            $query->orderByRaw('(dropoff_address ILIKE ?) DESC', ["%{$homeRegion}%"]);
        }

        return $query->orderByDesc('jobs.created_at');
    }

    /**
     * The single-job case used by returnLoadSuggestions()/claimReturnLoad()
     * — unchanged behavior (same 10-result cap) from before this was
     * generalized to support a multi-anchor set.
     */
    private function returnLoadCandidates(Job $fromJob, TransporterCompany $company): Builder
    {
        return $this->nearbyOpenJobsQuery([$fromJob->id], $company)->limit(10);
    }

    /**
     * Whether the viewing company already follows this job's customer
     * (Phase: Follow system) — a correlated subquery, same shape as
     * `customer_completed_jobs_count` above, so JobResource can render a
     * Follow/Following toggle without a second request per job.
     */
    private function isFollowingCustomerSelect(int $companyId): Builder
    {
        return CustomerFollow::selectRaw('count(*) > 0')
            ->whereColumn('customer_id', 'jobs.customer_id')
            ->where('transporter_company_id', $companyId);
    }

    private function applyPreferredRoutesFilter(Builder $query, TransporterCompany $company): void
    {
        if (! $company->is_featured) {
            return;
        }

        $routes = collect($company->preferred_routes ?? [])
            ->filter(fn ($route) => ! empty($route['origin']) && ! empty($route['destination']));

        if ($routes->isEmpty()) {
            return;
        }

        $query->where(function (Builder $outer) use ($routes) {
            foreach ($routes as $route) {
                $outer->orWhere(function (Builder $inner) use ($route) {
                    $inner->where('pickup_address', 'like', "%{$route['origin']}%")
                        ->where('dropoff_address', 'like', "%{$route['destination']}%");
                });
            }
        });
    }
}
