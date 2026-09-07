<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Resources\JobResource;
use App\Models\Job;
use App\Models\TransporterCompany;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

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
     * The open-jobs feed — any approved company can see and bid on any
     * open job (PRD §7.4: "any verified company can bid on any open job").
     * Featured companies may additionally filter to just their saved
     * preferred routes (AppFlow §2.7) via ?use_preferred_routes=1 — a
     * plain address-text match (origin/destination against pickup/
     * dropoff_address), not a geo query, since preferred_routes stores
     * free-text route descriptions, not coordinates. Ignored entirely for
     * a non-Featured company or one with no saved routes, rather than
     * erroring — this is a convenience filter, not a permission.
     */
    public function open(Request $request): AnonymousResourceCollection
    {
        $query = Job::withCoordinates()->where('status', 'open')->with('customer')->withCount('bids')->latest();

        if ($request->boolean('use_preferred_routes')) {
            $this->applyPreferredRoutesFilter($query, $request->user()->transporterCompany);
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
            ->withCount('bids')
            ->latest();

        return JobResource::collection($query->paginate(20));
    }

    /**
     * Jobs actually assigned to this company — ongoing work, not just a
     * bid still pending review.
     */
    public function active(Request $request): AnonymousResourceCollection
    {
        $companyId = $request->user()->transporterCompany->id;

        $query = Job::withCoordinates()
            ->where('assigned_company_id', $companyId)
            ->whereNotIn('status', ['cancelled'])
            ->with('customer')
            ->withCount('bids')
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
        $companyId = $request->user()->transporterCompany->id;

        $visible = $job->status === 'open'
            || $job->assigned_company_id === $companyId
            || $job->bids()->where('transporter_company_id', $companyId)->exists();

        abort_unless($visible, 404);

        // A company can legitimately view a job it lost the bid on (via
        // "My Bids") even after it's moved past 'open' — but only the
        // *assigned* company may see truck/driver-assignment actions on
        // it, so the app needs to tell those two cases apart.
        return (new JobResource(
            Job::withCoordinates()->withCount('bids')
                ->with(['assignedTruck', 'assignedDriver', 'proofOfDelivery', 'customer'])
                ->findOrFail($job->id)
        ))->additional(['is_assigned_to_viewer' => $job->assigned_company_id === $companyId]);
    }

    /**
     * "Find a return load" (AppFlow §2.7) — Featured-only, shown right
     * after a delivery: other open jobs whose pickup point is near where
     * this job just dropped off, a real PostGIS proximity query (unlike
     * the preferred-routes filter above, which is plain address text —
     * here the docs explicitly call for a geo query, and dropoff/pickup
     * are real geography columns).
     */
    public function returnLoadSuggestions(Request $request, Job $job): AnonymousResourceCollection
    {
        $company = $request->user()->transporterCompany;
        abort_unless($company->is_featured, 403, 'Return-load suggestions are a Featured-only feature.');
        abort_unless($job->assigned_company_id === $company->id, 404);
        abort_unless(in_array($job->status, ['delivered', 'completed'], true), 422);

        // 50km — a reasonable "nearby" radius for a return load; no
        // specific number exists in the docs, and this isn't exposed as a
        // platform_setting since nothing else needs it configurable yet.
        $radiusMeters = 50000;

        $suggestions = Job::withCoordinates()
            ->where('status', 'open')
            ->where('id', '!=', $job->id)
            ->whereRaw(
                'ST_DWithin(pickup_location, (SELECT dropoff_location FROM jobs WHERE id = ?), ?)',
                [$job->id, $radiusMeters],
            )
            ->withCount('bids')
            ->limit(10)
            ->get();

        return JobResource::collection($suggestions);
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
