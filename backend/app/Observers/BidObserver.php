<?php

namespace App\Observers;

use App\Models\Bid;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;

class BidObserver
{
    use ResolvesCurrentActor;

    /** @var array<string, string> */
    private const STATUS_ACTIONS = [
        'accepted' => 'bid_accepted',
        'rejected' => 'bid_rejected',
        'withdrawn' => 'bid_withdrawn',
    ];

    public function __construct(private readonly ActivityLogger $activityLogger) {}

    public function created(Bid $bid): void
    {
        $this->activityLogger->record('bid_placed', $bid, $this->currentActorId(), [
            'job_id' => $bid->job_id,
            'price' => (string) $bid->price,
        ]);
    }

    public function updated(Bid $bid): void
    {
        if (! $bid->wasChanged('status')) {
            return;
        }

        if ($action = self::STATUS_ACTIONS[$bid->status] ?? null) {
            $this->activityLogger->record($action, $bid, $this->currentActorId());
        }
    }
}
