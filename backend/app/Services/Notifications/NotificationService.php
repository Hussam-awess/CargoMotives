<?php

namespace App\Services\Notifications;

use App\Jobs\SendPushNotificationJob;
use App\Models\Job;
use App\Models\Notification;
use App\Models\User;

/**
 * The single place that ever writes a `notifications` row (Backend Schema
 * §2.18) — every event in AppFlow §6's Notification Trigger Map goes
 * through here, called from the model observers that already watch the
 * relevant state changes (Phase 9's activity_logs pattern, reused for the
 * same reason: an observer watching wasChanged() gets every existing and
 * future write path for free, instead of a call threaded into a dozen
 * controllers).
 *
 * Creating the row and dispatching the push are deliberately two separate
 * steps: the in-app notification is real and durable the instant this
 * method returns, regardless of whether Firebase is configured, reachable,
 * or the user has any device registered at all — a push is an enhancement
 * layered on top, never a requirement for the notification to exist (TRD
 * §5.3 graceful degradation, the same principle already applied to SMS/
 * mail/payment/GPS).
 */
class NotificationService
{
    public function send(User $user, string $type, string $title, string $body, ?Job $relatedJob = null): Notification
    {
        $notification = Notification::create([
            'user_id' => $user->id,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'related_job_id' => $relatedJob?->id,
        ]);

        SendPushNotificationJob::dispatch($notification->id);

        return $notification;
    }
}
