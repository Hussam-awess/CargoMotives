<?php

namespace App\Http\Resources;

use App\Models\User;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class UserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'account_type' => $this->account_type,
            'phone_number' => $this->phone_number,
            'email' => $this->email,
            'email_verified_at' => $this->email_verified_at?->toIso8601String(),
            'full_name' => $this->full_name,
            // A Customer's optional business identity (Phase 11) — null
            // for every other account_type.
            'company_name' => $this->company_name,
            'company_logo_url' => $this->company_logo_url
                ? app(DocumentStorage::class)->signedUrl($this->company_logo_url)
                : null,
            'language_preference' => $this->language_preference,
            'is_featured' => $this->is_featured,
        ];
    }
}
