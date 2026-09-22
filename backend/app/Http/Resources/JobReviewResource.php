<?php

namespace App\Http\Resources;

use App\Models\JobReview;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin JobReview
 */
class JobReviewResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'job_id' => $this->job_id,
            'rater_type' => $this->rater_type,
            'rater_name' => $this->whenLoaded('rater', fn () => $this->rater->full_name),
            'rating' => (int) $this->rating,
            'comment' => $this->comment,
            'category_ratings' => $this->category_ratings,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
