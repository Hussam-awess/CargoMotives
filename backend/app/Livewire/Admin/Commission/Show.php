<?php

namespace App\Livewire\Admin\Commission;

use App\Models\Payment;
use App\Models\TransporterCompany;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * One company's ledger history and payment attempts (PRD §10 item 7).
 * `payments.user_id` is the company owner (the payer) — see
 * App\Models\Payment's docblock — so payments are looked up via the
 * company's owner_user_id, not a direct company relation (none exists,
 * by design: a Payment can also be a Customer's Featured purchase).
 */
#[Layout('layouts.admin')]
class Show extends Component
{
    public TransporterCompany $company;

    public function mount(TransporterCompany $company): void
    {
        $this->company = $company->load('commissionLedgerEntries');
    }

    public function render()
    {
        $payments = Payment::where('user_id', $this->company->owner_user_id)
            ->where('purpose', 'commission_payment')
            ->latest()
            ->get();

        $ledger = $this->company->commissionLedgerEntries()->latest()->get();

        return view('livewire.admin.commission.show', compact('payments', 'ledger'));
    }
}
