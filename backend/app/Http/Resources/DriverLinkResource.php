<?php

namespace App\Http\Resources;

use App\Models\DriverLink;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin DriverLink
 */
class DriverLinkResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'url' => $this->resource->url(),
            'status' => $this->status,
            'expires_at' => $this->expires_at?->toIso8601String(),
            'driver_name' => $this->whenLoaded('driver', fn () => $this->driver->full_name),
        ];
    }
}
