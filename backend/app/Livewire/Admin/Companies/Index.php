<?php

namespace App\Livewire\Admin\Companies;

use App\Models\TransporterCompany;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * Company verification queue (PRD §10 item 1) — same filter shape as the
 * existing Sanctum-based AdminCompanyController::index() (Phase 2), just
 * rendered as a Livewire table instead of JSON. Both can coexist; this
 * doesn't replace that controller's routes.
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
        $query = TransporterCompany::query()->latest();

        if ($this->status !== '') {
            $query->where('verification_status', $this->status);
        }

        return view('livewire.admin.companies.index', [
            'companies' => $query->paginate(20),
        ]);
    }
}
