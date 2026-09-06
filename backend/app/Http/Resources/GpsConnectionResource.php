<?php

namespace App\Http\Resources;

use App\Models\GpsConnection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin GpsConnection
 */
class GpsConnectionResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'provider' => $this->provider,
            // access_token/refresh_token never leave this model, encrypted
            // or not (TRD §7) — nothing below this line ever needs them.
            'status' => $this->status,
            'connected_at' => $this->connected_at?->toIso8601String(),
            'last_synced_at' => $this->last_synced_at?->toIso8601String(),
        ];
    }
}
