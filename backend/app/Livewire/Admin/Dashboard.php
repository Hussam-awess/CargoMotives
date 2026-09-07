<?php

namespace App\Livewire\Admin;

use App\Models\CommissionLedger;
use App\Models\Job;
use App\Models\TransporterCompany;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * "Basic operational stats" (PRD §10 item 11) — deliberately "a handful
 * of numbers, not a reporting suite." The PRD names exactly these four;
 * resist the urge to add more without a real ask, per the Implementation
 * Plan's "What This Plan Deliberately Doesn't Do."
 */
#[Layout('layouts.admin')]
class Dashboard extends Component
{
    public function render()
    {
        return view('livewire.admin.dashboard', [
            'jobsPosted' => Job::count(),
            'jobsCompleted' => Job::where('status', 'completed')->count(),
            'activeCompanies' => TransporterCompany::where('verification_status', 'approved')->count(),
            'commissionCollected' => CommissionLedger::where('entry_type', 'payment')->sum('amount'),
        ]);
    }
}
