<?php

namespace App\Services\ActivityLog;

use App\Models\ActivityLog;
use Illuminate\Database\Eloquent\Model;

/**
 * The single place that ever writes an activity_logs row (Backend Schema
 * §2.16) — called exclusively from the App\Observers\* classes registered
 * in AppServiceProvider::boot(), never directly from a controller. Using
 * model observers instead of threading logging calls through every
 * controller from Phases 1-8 means every verification/job/bid/payment/
 * dispute state change gets logged automatically and consistently,
 * without relying on each call site remembering to do it.
 */
class ActivityLogger
{
    /**
     * @param  array<string, mixed>  $metadata
     */
    public function record(string $action, Model $subject, ?int $actorUserId, array $metadata = []): ActivityLog
    {
        return ActivityLog::create([
            'actor_user_id' => $actorUserId,
            'action' => $action,
            'subject_type' => $subject::class,
            'subject_id' => $subject->getKey(),
            'metadata' => $metadata === [] ? null : $metadata,
        ]);
    }
}
