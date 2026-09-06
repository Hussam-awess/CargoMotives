<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Resources\JobResource;
use App\Models\Job;
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
     */
    public function open(Request $request): AnonymousResourceCollection
    {
        $query = Job::withCoordinates()->where('status', 'open')->withCount('bids')->latest();

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
                ->with(['assignedTruck', 'assignedDriver', 'proofOfDelivery'])
                ->findOrFail($job->id)
        ))->additional(['is_assigned_to_viewer' => $job->assigned_company_id === $companyId]);
    }
}
