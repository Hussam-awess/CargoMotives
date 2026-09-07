<?php

namespace Tests\Unit\Services\Notifications;

use App\Jobs\SendPushNotificationJob;
use App\Models\Job;
use App\Models\User;
use App\Services\Notifications\NotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class NotificationServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_send_creates_a_notification_row_and_queues_a_push(): void
    {
        Queue::fake();

        $user = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $user->id]);

        $notification = (new NotificationService)->send($user, 'new_bid', 'New bid received', 'Someone bid on your job.', $job);

        $this->assertDatabaseHas('notifications', [
            'id' => $notification->id,
            'user_id' => $user->id,
            'type' => 'new_bid',
            'title' => 'New bid received',
            'body' => 'Someone bid on your job.',
            'related_job_id' => $job->id,
            'sent_via_fcm' => false,
        ]);

        Queue::assertPushed(SendPushNotificationJob::class, fn ($pushed) => $pushed->notificationId === $notification->id);
    }

    public function test_send_without_a_related_job_leaves_related_job_id_null(): void
    {
        Queue::fake();

        $user = User::factory()->create();

        $notification = (new NotificationService)->send($user, 'commission_hold_applied', 'Account on hold', 'Pay down your balance.');

        $this->assertNull($notification->related_job_id);
    }
}
