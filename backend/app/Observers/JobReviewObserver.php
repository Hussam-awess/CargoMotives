<?php

namespace App\Observers;

use App\Models\JobReview;
use App\Models\TransporterCompany;
use App\Models\User;

/**
 * Keeps the ratee's average_rating/rating_count current (Phase: ratings).
 * Recomputed from scratch on every new review rather than incrementally
 * maintained — a job produces at most two reviews total, so a full
 * AVG()/COUNT() over the ratee's reviews is cheap, and it can never drift
 * out of sync the way an incremental counter could.
 */
class JobReviewObserver
{
    public function created(JobReview $review): void
    {
        if ($review->ratee_company_id !== null) {
            $this->recompute(TransporterCompany::class, $review->ratee_company_id, 'ratee_company_id');
        }

        if ($review->ratee_customer_id !== null) {
            $this->recompute(User::class, $review->ratee_customer_id, 'ratee_customer_id');
        }
    }

    /**
     * @param  class-string<TransporterCompany|User>  $modelClass
     */
    private function recompute(string $modelClass, int $rateeId, string $column): void
    {
        $stats = JobReview::where($column, $rateeId)->selectRaw('avg(rating) as avg_rating, count(*) as review_count')->first();

        // Never mass-assigned: both columns are deliberately excluded from
        // each model's #[Fillable] (system-computed only), so a plain
        // update() here would silently discard them — set directly and
        // save(), same pattern as Job::completed_at.
        $model = $modelClass::findOrFail($rateeId);
        $model->average_rating = round((float) $stats->avg_rating, 1);
        $model->rating_count = (int) $stats->review_count;
        $model->save();
    }
}
