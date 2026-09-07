<?php

namespace App\Observers;

use App\Models\Bid;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;
use App\Services\Notifications\NotificationService;

class BidObserver
{
    use ResolvesCurrentActor;

    /** @var array<string, string> */
    private const STATUS_ACTIONS = [
        'accepted' => 'bid_accepted',
        'rejected' => 'bid_rejected',
        'withdrawn' => 'bid_withdrawn',
    ];

    public function __construct(
        private readonly ActivityLogger $activityLogger,
        private readonly NotificationService $notifications,
    ) {}

    public function created(Bid $bid): void
    {
        $this->activityLogger->record('bid_placed', $bid, $this->currentActorId(), [
            'job_id' => $bid->job_id,
            'price' => (string) $bid->price,
        ]);

        // AppFlow §6: "New bid (incl. Featured)" -> Customer, Push.
        $job = $bid->job;
        $this->notifications->send(
            $job->customer,
            'new_bid',
            'New bid received',
            "{$bid->company->company_name} bid {$bid->price} {$job->currency} on your job.",
            $job,
        );
    }

    public function updated(Bid $bid): void
    {
        if (! $bid->wasChanged('status')) {
            return;
        }

        if ($action = self::STATUS_ACTIONS[$bid->status] ?? null) {
            $this->activityLogger->record($action, $bid, $this->currentActorId());
        }

        // AppFlow §6: "Bid accepted / not selected" -> Companies involved,
        // Push. 'withdrawn' is the company's own action, not something to
        // notify it about.
        if ($bid->status === 'accepted') {
            $this->notifications->send(
                $bid->company->owner,
                'bid_accepted',
                'Bid accepted',
                "Your bid on Job #{$bid->job_id} was accepted. Assign a truck and driver to get started.",
                $bid->job,
            );
        } elseif ($bid->status === 'rejected') {
            $this->notifications->send(
                $bid->company->owner,
                'bid_not_selected',
                'Bid not selected',
                "Your bid on Job #{$bid->job_id} was not selected — the customer chose another company.",
                $bid->job,
            );
        }
    }
}
