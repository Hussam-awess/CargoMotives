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
            'last_known_speed_kmh' => $this->last_known_speed_kmh !== null ? (float) $this->last_known_speed_kmh : null,
            'last_known_at' => $this->last_known_at?->toIso8601String(),
            // Only ever populated for a provider that actually reports one
            // (Tracksolid Pro) — see the migration's own docblock. Never a
            // substitute for a real job's assigned driver.
            'gps_driver_name' => $this->gps_driver_name,
            // True once the truck has a live position within the same
            // "signal lost" window CheckGpsSignalLoss uses at the job
            // level — gps_status alone only means "a provider is linked,"
            // not "currently reporting."
            'gps_online' => $this->isGpsOnline(),
            // Fleet map marker color: true (green) while actively moving or
            // only briefly slow; false (red) once stationary for
            // config('gps.stationary_after_minutes') or GPS-offline
            // entirely — see Truck::isMoving()'s own docblock.
            'gps_moving' => $this->isMoving(),
            // Created directly from a GPS provider's device list rather
            // than the normal registration form (GpsConnectionController::
            // import()'s "add as new truck" path) — Manage Fleet shows an
            // "Imported from {provider}" label and an "Add details" action
            // for these instead of the usual verification-status chip set.
            'is_gps_imported' => (bool) $this->is_gps_imported,
            'gps_provider' => $this->whenLoaded('gpsConnection', fn () => $this->gpsConnection?->provider),
            'current_status' => $this->current_status,
            'is_active' => $this->is_active,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
