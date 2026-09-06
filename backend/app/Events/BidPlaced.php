<?php

namespace App\Events;

use App\Http\Resources\BidResource;
use App\Models\Bid;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast on job.{id} the moment a new bid is placed — one of exactly two
 * places this app uses WebSockets (TRD §4; the other is live GPS, Phase 6).
 * Broadcasting itself is fire-and-forget: if no client is subscribed to
 * this job's channel, the broadcast simply has no listener — the bid is
 * already saved and visible via the ordinary REST bid list regardless, so
 * a broadcast failure never blocks the underlying action (this doesn't
 * even implement ShouldQueue's failure handling specially, since a missed
 * live update degrades to "the customer sees it on next refresh," not a
 * lost bid).
 */
class BidPlaced implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Bid $bid) {}

    /**
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel("job.{$this->bid->job_id}")];
    }

    public function broadcastAs(): string
    {
        return 'bid.placed';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return (new BidResource($this->bid->loadMissing('company.trucks')))->resolve();
    }
}
