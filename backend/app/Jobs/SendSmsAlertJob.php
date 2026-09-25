<?php

namespace App\Jobs;

use App\Models\Notification;
use App\Models\User;
use App\Services\Sms\SmsGateway;
use App\Support\Pii;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * An SMS copy of an already-created shipment-update notification, for a
 * user who opted in to "SMS alerts" (a paid-per-message channel, so it is
 * never on by default — see User::OPT_IN_NOTIFICATION_CATEGORIES). Queued
 * for the same reason SendPushNotificationJob is: the in-app notification
 * is already durable, SMS is only an extra delivery channel on top.
 */
class SendSmsAlertJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, SerializesModels;

    public int $tries = 3;

    /** @var array<int, int> */
    public array $backoff = [30, 120];

    public function __construct(public int $notificationId) {}

    public function handle(SmsGateway $sms): void
    {
        $notification = Notification::find($this->notificationId);
        $user = $notification ? User::find($notification->user_id) : null;

        // Re-checked at send time, not just at dispatch time: the user may
        // have opted out (or deleted their account) while this was queued.
        if ($user === null || $user->phone_number === null || ! $user->wantsNotificationCategory('sms_alerts')) {
            return;
        }

        $result = $sms->send($user->phone_number, "Cargo Motives: {$notification->title}. {$notification->body}");

        if (! $result->successful) {
            Log::warning('SMS alert delivery failed', [
                'notification_id' => $notification->id,
                'phone' => Pii::maskPhone($user->phone_number),
                'error' => $result->error,
            ]);
        }
    }
}
