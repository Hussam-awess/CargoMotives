<?php

namespace App\Http\Resources;

use App\Models\Truck;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Truck
 */
class TruckResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $storage = app(DocumentStorage::class);
        $documents = $this->documents ?? [];

        return [
            'id' => $this->id,
            'registration_number' => $this->registration_number,
            'make_model' => $this->make_model,
            'vehicle_type' => $this->vehicle_type,
            'capacity_tons' => (float) $this->capacity_tons,
            // Every URL below is a private storage key on the model,
            // signed into a short-lived URL only here — see
            // App\Services\Documents\DocumentStorage.
            'photo_urls' => collect($documents['photos'] ?? [])
                ->map(fn (string $key) => $storage->signedUrl($key))
                ->all(),
            'registration_card_url' => isset($documents['registration_card'])
                ? $storage->signedUrl($documents['registration_card']) : null,
            'insurance_url' => isset($documents['insurance'])
                ? $storage->signedUrl($documents['insurance']) : null,
            'roadworthiness_permit_url' => isset($documents['roadworthiness_permit'])
                ? $storage->signedUrl($documents['roadworthiness_permit']) : null,
            'verification_status' => $this->verification_status,
            'verification_rejected_reason' => $this->verification_rejected_reason,
            'gps_status' => $this->gps_status,
            'last_known_lat' => $this->last_known_lat !== null ? (float) $this->last_known_lat : null,
            'last_known_lng' => $this->last_known_lng !== null ? (float) $this->last_known_lng : null,
            'last_known_heading' => $this->last_known_heading !== null ? (float) $this->last_known_heading : null,
            'last_known_at' => $this->last_known_at?->toIso8601String(),
            'current_status' => $this->current_status,
            'is_active' => $this->is_active,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
