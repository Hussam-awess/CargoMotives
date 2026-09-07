<?php

namespace App\Observers;

use App\Models\TransporterCompany;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;

class TransporterCompanyObserver
{
    use ResolvesCurrentActor;

    /**
     * verification_status values that map to a logged action — 'pending'
     * is the starting/reset state and isn't itself a reviewable decision
     * worth an audit entry.
     *
     * @var array<string, string>
     */
    private const VERIFICATION_ACTIONS = [
        'approved' => 'company_approved',
        'rejected' => 'company_rejected',
        'flagged_duplicate' => 'company_flagged_duplicate',
    ];

    public function __construct(private readonly ActivityLogger $activityLogger) {}

    public function updated(TransporterCompany $company): void
    {
        if ($company->wasChanged('verification_status') && $action = self::VERIFICATION_ACTIONS[$company->verification_status] ?? null) {
            $this->activityLogger->record($action, $company, $this->currentActorId());
        }

        if ($company->wasChanged('commission_standing')) {
            $this->activityLogger->record(
                $company->commission_standing === 'on_hold' ? 'commission_hold_applied' : 'commission_hold_lifted',
                $company,
                $this->currentActorId(),
                ['outstanding_balance' => (string) $company->outstanding_balance],
            );
        }
    }
}
