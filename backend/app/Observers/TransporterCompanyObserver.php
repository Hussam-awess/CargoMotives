<?php

namespace App\Observers;

use App\Models\TransporterCompany;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;
use App\Services\Notifications\NotificationService;

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

    public function __construct(
        private readonly ActivityLogger $activityLogger,
        private readonly NotificationService $notifications,
    ) {}

    public function updated(TransporterCompany $company): void
    {
        if ($company->wasChanged('verification_status') && $action = self::VERIFICATION_ACTIONS[$company->verification_status] ?? null) {
            $this->activityLogger->record($action, $company, $this->currentActorId());

            // AppFlow §6: "Company/truck verification approved/rejected" ->
            // Company, Push. A flagged_duplicate transition isn't itself a
            // decision (Admin hasn't ruled yet), so it's excluded here even
            // though it IS a logged action above.
            if (in_array($company->verification_status, ['approved', 'rejected'], true)) {
                $this->notifications->send(
                    $company->owner,
                    $action,
                    $company->verification_status === 'approved' ? 'Company verified' : 'Company verification rejected',
                    $company->verification_status === 'approved'
                        ? "{$company->company_name} has been verified. You can now register trucks and bid on jobs."
                        : "{$company->company_name}'s verification was rejected: {$company->verification_rejected_reason}",
                );
            }
        }

        if ($company->wasChanged('commission_standing')) {
            $this->activityLogger->record(
                $company->commission_standing === 'on_hold' ? 'commission_hold_applied' : 'commission_hold_lifted',
                $company,
                $this->currentActorId(),
                ['outstanding_balance' => (string) $company->outstanding_balance],
            );

            // AppFlow §6: "Commission balance nearing/over hold threshold"
            // -> Company, Push. Only the on_hold transition fires a push —
            // there's no clean "nearing" signal without extra
            // threshold-fraction logic this phase doesn't add.
            if ($company->commission_standing === 'on_hold') {
                $this->notifications->send(
                    $company->owner,
                    'commission_hold_applied',
                    'Account on hold',
                    "Your outstanding balance of {$company->outstanding_balance} TZS has crossed the hold threshold. Pay it down to resume bidding.",
                );
            }
        }
    }
}
