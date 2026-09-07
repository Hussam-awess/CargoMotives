<?php

namespace App\Livewire\Admin\Trucks;

use App\Models\Truck;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Truck verification detail + approve/reject (PRD §10 item 2).
 */
#[Layout('layouts.admin')]
class Show extends Component
{
    public Truck $truck;

    public string $rejectReason = '';

    public bool $showRejectForm = false;

    /**
     * Rendered inline by this component's own view — see
     * App\Livewire\Admin\Companies\Show's identical property for why
     * session()->flash() silently never shows through a Livewire action.
     */
    public ?string $statusMessage = null;

    public function mount(Truck $truck): void
    {
        $this->truck = $truck->load('company');
    }

    public function approve(): void
    {
        $this->truck->update(['verification_status' => 'approved', 'verification_rejected_reason' => null]);

        $this->statusMessage = "{$this->truck->registration_number} approved.";
    }

    public function reject(): void
    {
        $this->validate(['rejectReason' => ['required', 'string', 'max:1000']]);

        $this->truck->update([
            'verification_status' => 'rejected',
            'verification_rejected_reason' => $this->rejectReason,
        ]);

        $this->showRejectForm = false;
        $this->rejectReason = '';
        $this->statusMessage = "{$this->truck->registration_number} rejected.";
    }

    public function render()
    {
        return view('livewire.admin.trucks.show');
    }
}
