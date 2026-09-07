<?php

namespace App\Livewire\Admin\Companies;

use App\Models\TransporterCompany;
use App\Services\Company\CompanyDuplicateDetector;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Company verification detail + approve/reject (PRD §10 item 1), plus the
 * side-by-side conflict comparison for a flagged_duplicate company — the
 * same data AdminCompanyController::show()/conflictSummary() (Phase 2)
 * already exposes over the API, reused here for the same job.
 */
#[Layout('layouts.admin')]
class Show extends Component
{
    public TransporterCompany $company;

    public string $rejectReason = '';

    public bool $showRejectForm = false;

    /**
     * Rendered inline by this component's own view, not
     * session()->flash() — a Livewire action is an AJAX partial update
     * that never re-renders the surrounding Blade layout, so a flash
     * message read there (layouts/admin.blade.php's old `session('status')`
     * check) would silently never appear. Caught live, not by any
     * automated test (Livewire::test() reads the rendered HTML directly,
     * which never exercises the layout wrapper at all).
     */
    public ?string $statusMessage = null;

    public function mount(TransporterCompany $company): void
    {
        $this->company = $company;
    }

    public function approve(): void
    {
        $this->company->update([
            'verification_status' => 'approved',
            'verification_rejected_reason' => null,
            'verified_at' => now(),
        ]);

        $this->statusMessage = "{$this->company->company_name} approved.";
    }

    public function reject(): void
    {
        $this->validate(['rejectReason' => ['required', 'string', 'max:1000']]);

        $this->company->update([
            'verification_status' => 'rejected',
            'verification_rejected_reason' => $this->rejectReason,
            'verified_at' => null,
        ]);

        $this->showRejectForm = false;
        $this->rejectReason = '';
        $this->statusMessage = "{$this->company->company_name} rejected.";
    }

    public function render()
    {
        $conflict = $this->company->verification_status === 'flagged_duplicate'
            ? app(CompanyDuplicateDetector::class)->conflictingCompany(
                $this->company->registration_number,
                $this->company->tin,
                $this->company->rep_national_id_number,
                excludingCompanyId: $this->company->id,
            )
            : null;

        return view('livewire.admin.companies.show', ['conflict' => $conflict]);
    }
}
