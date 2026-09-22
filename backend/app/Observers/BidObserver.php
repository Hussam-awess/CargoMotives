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

        // AppFlow §6: "New bid (incl. Featured)" -> Customer, Push. A
        // return-load claim (Cargo Motives Plus benefit) is worded
        // differently — it's a one-tap match at the job's own stated
        // price, not a competitive offer the customer needs to compare
        // against others, so it shouldn't read like one.
        $job = $bid->job;
        if ($bid->is_return_load_claim) {
            $this->notifications->send(
                $job->customer,
                'return_load_claim',
                'A transporter wants your job',
                "{$bid->company->company_name} wants to take your job as a return load at your posted price ({$bid->price} {$job->currency}) — no bidding, just confirm to assign it.",
                $job,
            );
        } else {
            $this->notifications->send(
                $job->customer,
                'new_bid',
                'New bid received',
                "{$bid->company->company_name} bid {$bid->price} {$job->currency} on your job.",
                $job,
            );
        }
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
