<?php

namespace App\Livewire\Admin\Jobs;

use App\Models\ActivityLog;
use App\Models\Bid;
use App\Models\Job;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * "Job details — drill into one job's full timeline, bid, and
 * assignment" (PRD §10 items 5-6, folded into one tool per TRD §8:
 * "assignment visibility (part of job detail)"). The timeline reads
 * activity_logs rows already written by JobObserver/BidObserver —
 * nothing here writes a log entry itself, this is a pure read view.
 */
#[Layout('layouts.admin')]
class Show extends Component
{
    public Job $job;

    public function mount(Job $job): void
    {
        $this->job = Job::withCoordinates()
            ->with(['customer', 'assignedCompany', 'assignedTruck', 'assignedDriver', 'bids.company', 'proofOfDelivery', 'disputes'])
            ->findOrFail($job->id);
    }

    public function render()
    {
        $timeline = ActivityLog::where(function ($q) {
            $q->where('subject_type', Job::class)->where('subject_id', $this->job->id);
        })->orWhere(function ($q) {
            $q->where('subject_type', Bid::class)->whereIn('subject_id', $this->job->bids->pluck('id'));
        })
            ->with('actor')
            ->latest('id')
            ->get();

        return view('livewire.admin.jobs.show', ['timeline' => $timeline]);
    }
}
