<?php

namespace App\Livewire\Admin\Disputes;

use App\Models\Dispute;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * Disputes queue (PRD §10 item 8) — defaults to 'open' so the queue
 * starts on what actually needs attention, rather than a full history.
 */
#[Layout('layouts.admin')]
class Index extends Component
{
    use WithPagination;

    #[Url]
    public string $status = 'open';

    public function updatedStatus(): void
    {
        $this->resetPage();
    }

    public function render()
    {
        $query = Dispute::query()->with(['job', 'raisedBy'])->latest();

        if ($this->status !== '') {
            $query->where('status', $this->status);
        }

        return view('livewire.admin.disputes.index', [
            'disputes' => $query->paginate(20),
        ]);
    }
}
