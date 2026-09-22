<?php

namespace App\Http\Resources;

use App\Models\User;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A customer as shown to a transporter company that follows them —
 * deliberately thin compared to UserResource (which is the "my own
 * profile" shape and includes phone/email): contact between the two
 * parties always goes through the in-app Message feature, never a
 * publicly/cross-account exposed phone number or email.
 *
 * @mixin User
 */
class FollowedCustomerResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'full_name' => $this->full_name,
            'company_name' => $this->company_name,
            'company_logo_url' => $this->company_logo_url
                ? app(DocumentStorage::class)->signedUrl($this->company_logo_url)
                : null,
        ];
    }
}
