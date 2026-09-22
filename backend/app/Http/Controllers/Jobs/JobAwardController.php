<?php

namespace App\Http\Controllers\Jobs;

use App\Http\Controllers\Controller;
use App\Http\Resources\JobResource;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\Truck;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The Multi-Company Split Awards epic's per-award equivalent of
 * JobController::confirmDelivery() — that method is never called for a job
 * that has any awards (mobile routes per-award confirmation here instead).
 * A job with 2+ awards only has one shared jobs.status once EVERY award is
 * independently completed; there is no "the" delivery to confirm at the
 * job level.
 */
class JobAwardController extends Controller
{
    public function confirmDelivery(Request $request, Job $job, JobAward $award): JobResource
    {
        abort_unless($job->customer_id === $request->user()->id, 404);
        abort_unless($award->job_id === $job->id, 404);

        if ($award->status !== 'delivered') {
            throw ValidationException::withMessages([
                'status' => ['This award has no delivery awaiting confirmation.'],
            ]);
        }

        DB::transaction(function () use ($job, $award) {
            $award->update(['status' => 'completed', 'completed_at' => now()]);
            $award->proofOfDelivery()->update(['confirmed_by_customer_at' => now()]);

            Truck::whereIn('id', $award->truckAssignments()->pluck('truck_id'))
                ->update(['current_status' => 'idle']);

            // Every award must be completed before the job as a whole is —
            // a job with 2+ awards has no single company's delivery that
            // "finishes" it on its own.
            $stillOpen = JobAward::where('job_id', $job->id)
                ->where('status', '!=', 'completed')
                ->exists();

            if (! $stillOpen) {
                $job->update(['status' => 'completed']);
                // completed_at is deliberately excluded from Job's
                // #[Fillable] (system-set only) — see JobController::
                // confirmDelivery() for the same pattern.
                $job->completed_at = now();
                $job->save();
            }
        });

        return new JobResource(
            Job::withCoordinates()
                ->with(['awards.company', 'awards.truckAssignments.truck', 'awards.truckAssignments.driver', 'awards.proofOfDelivery'])
                ->findOrFail($job->id)
        );
    }
}
