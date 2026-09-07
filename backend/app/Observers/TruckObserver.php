<?php

namespace App\Observers;

use App\Models\Truck;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;

class TruckObserver
{
    use ResolvesCurrentActor;

    /** @var array<string, string> */
    private const VERIFICATION_ACTIONS = [
        'approved' => 'truck_approved',
        'rejected' => 'truck_rejected',
    ];

    public function __construct(private readonly ActivityLogger $activityLogger) {}

    public function updated(Truck $truck): void
    {
        if (! $truck->wasChanged('verification_status')) {
            return;
        }

        if ($action = self::VERIFICATION_ACTIONS[$truck->verification_status] ?? null) {
            $this->activityLogger->record($action, $truck, $this->currentActorId());
        }
    }
}
