<?php

namespace App\Http\Resources;

use App\Models\SupportMessage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Same shape as MessageResource deliberately — the mobile app's existing
 * MessagesScreen bubble UI (built for the per-job Message model) can
 * render a Support thread with zero changes as long as the wire shape
 * matches: id, body, is_mine, created_at.
 *
 * @mixin SupportMessage
 */
class SupportMessageResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'body' => $this->body,
            'is_mine' => $this->author === 'user',
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
