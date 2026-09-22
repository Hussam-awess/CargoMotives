<?php

namespace App\Http\Resources;

use App\Models\JobReview;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One review as shown on a public profile (Phase: public profiles) —
 * deliberately anonymous about the rater, same reasoning as a profile's
 * "recent completed jobs" list: this is a reliability signal for anyone
 * viewing the profile, not a conversation between two named parties.
 *
 * @mixin JobReview
 */
class PublicReviewResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'rating' => (int) $this->rating,
            'comment' => $this->comment,
            'category_ratings' => $this->category_ratings,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
