<?php

namespace App\Livewire\Admin\ActivityLog;

use App\Models\ActivityLog;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * "Activity/audit log — a chronological record of verification, job, bid,
 * and payment events" (PRD §10 item 9) — "a single activity log view"
 * per TRD §8, reading the one activity_logs table every observer in
 * app/Observers writes to.
 */
#[Layout('layouts.admin')]
class Index extends Component
{
    use WithPagination;

    #[Url]
    public string $action = '';

    public function updatedAction(): void
    {
        $this->resetPage();
    }

    public function render()
    {
        $query = ActivityLog::query()->with('actor')->latest('id');

        if ($this->action !== '') {
            $query->where('action', $this->action);
        }

        return view('livewire.admin.activity-log.index', [
            'entries' => $query->paginate(30),
            'actions' => ActivityLog::query()->distinct()->orderBy('action')->pluck('action'),
        ]);
    }
}
