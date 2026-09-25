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
            'avatar_url' => $this->avatar_url
                ? app(DocumentStorage::class)->signedUrl($this->avatar_url)
                : null,
            // A Customer's optional business identity (Phase 11) — null
            // for every other account_type.
            'company_name' => $this->company_name,
            'company_logo_url' => $this->company_logo_url
                ? app(DocumentStorage::class)->signedUrl($this->company_logo_url)
                : null,
            'language_preference' => $this->language_preference,
            // A denomination choice only — no conversion/exchange-rate
            // system exists here, see the migration's own docblock.
            'preferred_currency' => $this->preferred_currency,
            'is_featured' => $this->is_featured,
            'two_factor_enabled' => (bool) $this->two_factor_enabled,
            // Resolved with defaults filled in (see
            // User::wantsNotificationCategory) so the client never has to
            // know the opt-out vs opt-in semantics itself, just render the
            // toggles.
            'notification_preferences' => [
                'bids' => $this->wantsNotificationCategory('bids'),
                'shipment_updates' => $this->wantsNotificationCategory('shipment_updates'),
                'messages' => $this->wantsNotificationCategory('messages'),
                'new_job_matches' => $this->wantsNotificationCategory('new_job_matches'),
                'sms_alerts' => $this->wantsNotificationCategory('sms_alerts'),
                'promotions' => $this->wantsNotificationCategory('promotions'),
            ],
        ];
    }
}
