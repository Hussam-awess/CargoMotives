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
    /**
     * Maps a notification `type` to the Settings-screen toggle that gates
     * it (App::Companies\Settings / Customer\Settings). A type not listed
     * here (verification outcomes, the inactivity nudge) is never gated —
     * those are outcomes a user needs to know about regardless of their
     * discretionary preferences, not the kind of thing a "notifications"
     * toggle is meant to quiet.
     *
     * @var array<string, string>
     */
    private const CATEGORY_BY_TYPE = [
        'new_bid' => 'bids',
        'bid_accepted' => 'bids',
        'bid_not_selected' => 'bids',
        'proof_of_delivery_submitted' => 'shipment_updates',
        'delivery_confirmed' => 'shipment_updates',
        'gps_signal_lost' => 'shipment_updates',
        'new_message' => 'messages',
        'support_message' => 'messages',
        'new_job_posted' => 'new_job_matches',
    ];

    public function send(User $user, string $type, string $title, string $body, ?Job $relatedJob = null): ?Notification
    {
        $category = self::CATEGORY_BY_TYPE[$type] ?? null;

        if ($category !== null && ! $user->wantsNotificationCategory($category)) {
            return null;
        }

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
