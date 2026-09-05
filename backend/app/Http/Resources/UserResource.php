<?php

namespace App\Http\Resources;

use App\Models\User;
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
            'full_name' => $this->full_name,
            'language_preference' => $this->language_preference,
            'is_featured' => $this->is_featured,
        ];
    }
}
