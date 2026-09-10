<?php

namespace App\Observers;

use App\Models\SupportMessage;
use App\Services\Notifications\NotificationService;

/**
 * Notification-only, mirroring MessageObserver's own reasoning — only an
 * admin's message to a user is worth notifying about; a user's own reply
 * has no one to notify (Admin has no push channel, only the web panel).
 */
class SupportMessageObserver
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function created(SupportMessage $message): void
    {
        if ($message->author !== 'admin') {
            return;
        }

        $this->notifications->send(
            $message->user,
            'support_message',
            'New message from Cargo Motives Support',
            $message->body,
        );
    }
}
