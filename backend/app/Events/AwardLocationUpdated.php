<?php

namespace App\Events;

use App\Models\JobAward;
use App\Models\Truck;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * The Multi-Company Split Awards epic's equivalent of TruckLocationUpdated
 * — broadcasts one company's award-scoped lead truck position on its OWN
 * channel, never the job-level one, since two unrelated companies' live
 * positions must never appear on the same private channel.
 */
class AwardLocationUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public JobAward $award, public Truck $truck) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel("award.{$this->award->id}.location")];
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
            'speed_kmh' => $this->truck->last_known_speed_kmh !== null ? (float) $this->truck->last_known_speed_kmh : null,
            'recorded_at' => $this->truck->last_known_at?->toIso8601String(),
            'gps_signal_status' => $this->award->gps_signal_status,
        ];
    }
}
