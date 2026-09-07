<?php

namespace App\Jobs;

use App\Models\DeviceToken;
use App\Models\Notification;
use App\Services\Push\PushGateway;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Delivers one already-created Notification row as a real push (TRD's
 * architecture diagram lists "notifications" alongside SMS/GPS
 * normalization/payment webhooks as exactly the kind of work that "runs
 * off the request cycle" via a queue worker) — the in-app notification
 * itself is already durable the moment NotificationService::send()
 * returns; this job only ever affects whether a device also buzzed.
 */
class SendPushNotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, SerializesModels;

    public function __construct(public int $notificationId) {}

    public function handle(PushGateway $push): void
    {
        $notification = Notification::find($this->notificationId);
        if ($notification === null) {
            return;
        }

        $tokens = DeviceToken::where('user_id', $notification->user_id)->pluck('token')->all();
        if ($tokens === []) {
            // No device registered for this user — the in-app notification
            // still exists and will show the next time they open the app.
            return;
        }

        $result = $push->send($tokens, $notification->title, $notification->body, [
            'notification_id' => (string) $notification->id,
            'type' => $notification->type,
            'related_job_id' => $notification->related_job_id !== null ? (string) $notification->related_job_id : '',
        ]);

        if ($result->invalidTokens !== []) {
            DeviceToken::whereIn('token', $result->invalidTokens)->delete();
        }

        if ($result->successful) {
            $notification->update(['sent_via_fcm' => true]);
        }
    }
}
