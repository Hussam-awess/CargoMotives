<?php

namespace App\Observers;

use App\Models\Job;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;

class JobObserver
{
    use ResolvesCurrentActor;

    public function __construct(private readonly ActivityLogger $activityLogger) {}

    public function updated(Job $job): void
    {
        if (! $job->wasChanged('status')) {
            return;
        }

        $this->activityLogger->record('job_status_changed', $job, $this->currentActorId(), [
            'from' => $job->getOriginal('status'),
            'to' => $job->status,
        ]);
    }
}
