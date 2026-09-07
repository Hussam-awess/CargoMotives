<?php

namespace App\Observers;

use App\Models\Truck;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;
use App\Services\Notifications\NotificationService;

class TruckObserver
{
    use ResolvesCurrentActor;

    /** @var array<string, string> */
    private const VERIFICATION_ACTIONS = [
        'approved' => 'truck_approved',
        'rejected' => 'truck_rejected',
    ];

    public function __construct(
        private readonly ActivityLogger $activityLogger,
        private readonly NotificationService $notifications,
    ) {}

    public function updated(Truck $truck): void
    {
        if (! $truck->wasChanged('verification_status')) {
            return;
        }

        if ($action = self::VERIFICATION_ACTIONS[$truck->verification_status] ?? null) {
            $this->activityLogger->record($action, $truck, $this->currentActorId());

            // AppFlow §6: "Company/truck verification approved/rejected" -> Company, Push.
            $this->notifications->send(
                $truck->company->owner,
                $action,
                $truck->verification_status === 'approved' ? 'Truck verified' : 'Truck verification rejected',
                $truck->verification_status === 'approved'
                    ? "Truck {$truck->registration_number} has been verified and is ready to be assigned."
                    : "Truck {$truck->registration_number}'s verification was rejected: {$truck->verification_rejected_reason}",
            );
        }
    }
}
