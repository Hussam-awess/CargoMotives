<?php

namespace App\Observers;

use App\Models\Dispute;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;

class DisputeObserver
{
    use ResolvesCurrentActor;

    public function __construct(private readonly ActivityLogger $activityLogger) {}

    public function created(Dispute $dispute): void
    {
        $this->activityLogger->record('dispute_raised', $dispute, $this->currentActorId(), [
            'job_id' => $dispute->job_id,
        ]);
    }

    public function updated(Dispute $dispute): void
    {
        if ($dispute->wasChanged('status') && $dispute->status === 'resolved') {
            $this->activityLogger->record('dispute_resolved', $dispute, $this->currentActorId(), [
                'job_id' => $dispute->job_id,
            ]);
        }
    }
}
