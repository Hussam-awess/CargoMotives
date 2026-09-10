<?php

namespace App\Livewire\Admin;

use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * "Basic operational stats" (PRD §10 item 11) — deliberately "a handful
 * of numbers, not a reporting suite." Resist the urge to add more without
 * a real ask, per the Implementation Plan's "What This Plan Deliberately
 * Doesn't Do."
 *
 * plusSubscribers replaces the old commissionCollected figure (Phase
 * 10.13): the platform no longer takes a commission at all, so the
 * dashboard's one money-adjacent stat now reflects the actual revenue
 * product — active Customer + Company Plus subscriptions.
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
            'plusSubscribers' => User::where('is_featured', true)->count()
                + TransporterCompany::where('is_featured', true)->count(),
        ]);
    }
}
