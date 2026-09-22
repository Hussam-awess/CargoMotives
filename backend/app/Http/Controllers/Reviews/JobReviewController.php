<?php

namespace App\Http\Controllers\Reviews;

use App\Http\Controllers\Controller;
use App\Http\Requests\Reviews\StoreJobReviewRequest;
use App\Http\Resources\JobReviewResource;
use App\Models\Job;
use App\Models\JobReview;
use Illuminate\Database\QueryException;
use Illuminate\Validation\ValidationException;

/**
 * Two-way ratings (Phase: ratings) — after a job reaches 'completed', the
 * customer can rate the transporter and the transporter can rate the
 * customer, each exactly once. See JobReview's migration for the schema
 * shape and JobReviewObserver for how a new review updates the ratee's
 * reliability stats.
 */
class JobReviewController extends Controller
{
    public function store(StoreJobReviewRequest $request, Job $job): JobReviewResource
    {
        $user = $request->user();
        $isCustomerRating = $job->customer_id === $user->id;
        $isAssignedCompanyOwner = $job->assignedCompany?->owner_user_id === $user->id;

        abort_unless($isCustomerRating || $isAssignedCompanyOwner, 404);

        if ($job->status !== 'completed') {
            throw ValidationException::withMessages(['job' => ['This job has not been completed yet.']]);
        }

        if (JobReview::where('job_id', $job->id)->where('rater_user_id', $user->id)->exists()) {
            throw ValidationException::withMessages(['job' => ['You have already rated this job.']]);
        }

        // Phase 5 polish: this existence check above can't fully close a
        // genuine race (two rapid submissions, e.g. a network retry,
        // landing before either has inserted) — the DB's own unique index
        // on (job_id, rater_user_id) is the real backstop for that, same
        // two-layer pattern as CompanyVerificationService::approve(). Caught
        // here and translated into the same clean, already-rated message
        // rather than surfacing a raw 500 for what the user experiences as
        // an ordinary double-tap.
        try {
            $review = JobReview::create([
                'job_id' => $job->id,
                'rater_type' => $isCustomerRating ? 'customer' : 'transporter_company',
                'rater_user_id' => $user->id,
                'ratee_customer_id' => $isCustomerRating ? null : $job->customer_id,
                'ratee_company_id' => $isCustomerRating ? $job->assigned_company_id : null,
                'rating' => $request->integer('rating'),
                'comment' => $request->string('comment')->toString() ?: null,
                'category_ratings' => $request->input('category_ratings'),
            ]);
        } catch (QueryException $e) {
            if (($e->errorInfo[0] ?? null) === '23505') {
                throw ValidationException::withMessages(['job' => ['You have already rated this job.']]);
            }

            throw $e;
        }

        return new JobReviewResource($review);
    }
}
