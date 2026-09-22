<?php

namespace App\Http\Resources;

use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Message
 */
class MessageResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'body' => $this->body,
            // Relative to whoever's asking — a chat bubble needs to know
            // "is this mine," not the raw sender id, on both sides of the
            // same conversation.
            'is_mine' => $this->sender_user_id === $request->user()->id,
            // Plus tint (Phase 3c) — a customer's own is_featured is real
            // Customer Plus; a company owner's own is_featured is unused
            // (that flag is Customer-Plus-only), so their Plus status
            // comes from their TransporterCompany instead. Exactly one of
            // the two is ever true for a given sender, so an OR is safe.
            'sender_is_featured' => $this->sender->is_featured || ($this->sender->transporterCompany?->is_featured ?? false),
            'read_at' => $this->read_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
