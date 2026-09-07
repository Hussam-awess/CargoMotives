<?php

namespace App\Livewire\Admin\Trucks;

use App\Models\Truck;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * Truck verification queue (PRD §10 item 2) — same filter shape as
 * AdminTruckController::index() (Phase 3), rendered as a Livewire table.
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
        $query = Truck::query()->with('company')->latest();

        if ($this->status !== '') {
            $query->where('verification_status', $this->status);
        }

        return view('livewire.admin.trucks.index', [
            'trucks' => $query->paginate(20),
        ]);
    }
}
