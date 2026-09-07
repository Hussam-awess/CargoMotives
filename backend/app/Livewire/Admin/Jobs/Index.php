<?php

namespace App\Livewire\Admin\Jobs;

use App\Models\Job;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * "Job management — list/filter all jobs" (PRD §10 item 4). Same
 * inline-filter convention as Companies/Trucks — filtered by status,
 * since that's the one dimension every other list/detail screen in this
 * app already filters jobs by (CompanyJobController, JobController).
 */
#[Layout('layouts.admin')]
class Index extends Component
{
    use WithPagination;

    #[Url]
    public string $status = '';

    public function updatedStatus(): void
    {
        $this->resetPage();
    }

    public function render()
    {
        $query = Job::query()->with(['customer', 'assignedCompany'])->latest();

        if ($this->status !== '') {
            $query->where('status', $this->status);
        }

        return view('livewire.admin.jobs.index', [
            'jobs' => $query->paginate(20),
            'statuses' => ['open', 'assigned', 'en_route_pickup', 'picked_up', 'in_transit', 'delivered', 'completed', 'cancelled'],
        ]);
    }
}
