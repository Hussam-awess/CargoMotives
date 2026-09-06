<?php

namespace App\Http\Resources;

use App\Models\ProofOfDelivery;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ProofOfDelivery
 */
class ProofOfDeliveryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $documents = app(DocumentStorage::class);

        return [
            'photo_urls' => collect($this->photo_urls)->map(fn (string $key) => $documents->signedUrl($key))->all(),
            'recipient_name' => $this->recipient_name,
            'notes' => $this->notes,
            'confirmed_by_customer_at' => $this->confirmed_by_customer_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
