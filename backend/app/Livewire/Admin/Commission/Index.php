<?php

namespace App\Livewire\Admin\Commission;

use App\Models\TransporterCompany;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * "Commission/payment status — company balances, holds, and payment
 * history" (PRD §10 item 7) — a company-wide read-only view; the detail
 * screen drills into one company's actual payments and ledger entries.
 * Deliberately only reads TransporterCompany.outstanding_balance/
 * commission_standing and CommissionLedger rows — never writes them; see
 * App\Services\Commission\CommissionLedgerService's docblock on why
 * that's the only writer.
 */
#[Layout('layouts.admin')]
class Index extends Component
{
    use WithPagination;

    #[Url]
    public string $standing = '';

    public function updatedStanding(): void
    {
        $this->resetPage();
    }

    public function render()
    {
        $query = TransporterCompany::where('verification_status', 'approved')->orderByDesc('outstanding_balance');

        if ($this->standing !== '') {
            $query->where('commission_standing', $this->standing);
        }

        return view('livewire.admin.commission.index', [
            'companies' => $query->paginate(20),
        ]);
    }
}
