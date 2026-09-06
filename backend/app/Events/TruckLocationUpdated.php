<?php

namespace App\Events;

use App\Models\Job;
use App\Models\Truck;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * The second (and last) real-time use case in this app (TRD §4/§5.2):
 * broadcasts a truck's freshly-normalized position on its currently
 * active job's private location channel. Fired from NormalizeGpsPositionJob
 * only when the truck is actually on a trackable job — a position update
 * for an idle truck has nothing to broadcast to.
 */
class TruckLocationUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Job $job, public Truck $truck) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel("job.{$this->job->id}.location")];
    }

    public function broadcastAs(): string
    {
        return 'location.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'lat' => (float) $this->truck->last_known_lat,
            'lng' => (float) $this->truck->last_known_lng,
            'heading' => $this->truck->last_known_heading !== null ? (float) $this->truck->last_known_heading : null,
            'recorded_at' => $this->truck->last_known_at?->toIso8601String(),
            'gps_signal_status' => $this->job->gps_signal_status,
        ];
    }
}
