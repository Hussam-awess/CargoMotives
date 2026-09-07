<?php

namespace App\Livewire\Admin\Disputes;

use App\Models\Dispute;
use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Dispute review + resolution (PRD §10 item 8): "review and resolve,
 * using proof of delivery and (when available) GPS history as evidence."
 * The docs describe no specific resolution actions beyond a note — no
 * refund/ledger-adjustment workflow is specified anywhere (TRD is silent
 * on it too), so this deliberately only records a decision + note; a
 * financial-adjustment tool is a real future addition, not something to
 * guess the shape of here.
 */
#[Layout('layouts.admin')]
class Show extends Component
{
    public Dispute $dispute;

    public string $resolutionNote = '';

    public function mount(Dispute $dispute): void
    {
        $this->dispute = $dispute->load([
            'job.assignedCompany', 'job.assignedTruck', 'job.proofOfDelivery', 'job.locationSnapshots', 'raisedBy',
        ]);
    }

    public function markUnderReview(): void
    {
        $this->dispute->update(['status' => 'under_review']);
    }

    public function resolve(): void
    {
        $this->validate(['resolutionNote' => ['required', 'string', 'max:1000']]);

        $this->dispute->update([
            'status' => 'resolved',
            'resolution_note' => $this->resolutionNote,
            'resolved_by_admin_id' => Auth::guard('web')->id(),
            'resolved_at' => now(),
        ]);
        // No separate confirmation banner needed here (unlike
        // Companies/Trucks/Settings) — the view's own "Resolution" section
        // (rendered once $dispute->status === 'resolved') already shows
        // the note and timestamp, which is confirmation enough.
    }

    public function render()
    {
        return view('livewire.admin.disputes.show');
    }
}
