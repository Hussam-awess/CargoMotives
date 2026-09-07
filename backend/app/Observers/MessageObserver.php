<?php

namespace App\Observers;

use App\Models\Message;
use App\Services\Notifications\NotificationService;

/**
 * Notification-only — unlike every other observer in this app, Messages
 * are deliberately never audit-logged (Phase 8's own decision: messaging
 * isn't one of the schema doc's activity_logs action examples, and a
 * message body isn't the kind of thing an audit trail needs to retain
 * twice). This observer exists solely to satisfy AppFlow §6's "New
 * message -> Customer / Company, Push" row.
 */
class MessageObserver
{
    public function __construct(private readonly NotificationService $notifications) {}

    public function created(Message $message): void
    {
        $job = $message->job;
        $isFromCustomer = $message->sender_user_id === $job->customer_id;

        $recipient = $isFromCustomer ? $job->assignedCompany->owner : $job->customer;

        $this->notifications->send(
            $recipient,
            'new_message',
            'New message',
            "New message on Job #{$job->id}: {$message->body}",
            $job,
        );
    }
}
