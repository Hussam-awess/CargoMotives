<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Requests\Jobs\AssignJobRequest;
use App\Http\Resources\DriverLinkResource;
use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
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
        $this->authorizeCompanyOwnership($request, $job);

        $truck = Truck::where('transporter_company_id', $request->user()->transporterCompany->id)
            ->findOrFail($request->integer('truck_id'));
        $driver = Driver::where('transporter_company_id', $request->user()->transporterCompany->id)
            ->findOrFail($request->integer('driver_id'));

        $link = $this->assignment->assign($job, $truck, $driver);

        return new DriverLinkResource($link->load('driver'));
    }

    /**
     * Re-fetches the job's current Driver Link so the company app can
     * display/re-share it any time — not just in the moment right after
     * assigning (AppFlow §2.5: "shows it in-app to re-share if needed").
     */
    public function driverLink(Request $request, Job $job): DriverLinkResource
    {
        $this->authorizeCompanyOwnership($request, $job);

        $link = DriverLink::where('job_id', $job->id)->where('status', 'active')->latest()->firstOrFail();

        return new DriverLinkResource($link->load('driver'));
    }

    private function authorizeCompanyOwnership(Request $request, Job $job): void
    {
        abort_unless($job->assigned_company_id === $request->user()->transporterCompany->id, 404);
    }
}
