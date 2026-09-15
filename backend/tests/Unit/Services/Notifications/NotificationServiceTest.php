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

        $notification = (new NotificationService)->send($user, 'support_message', 'Support', 'Hello.');

        $this->assertNull($notification->related_job_id);
    }

    public function test_a_user_who_disabled_a_category_is_not_notified(): void
    {
        Queue::fake();

        $user = User::factory()->create(['notification_preferences' => ['bids' => false]]);

        $result = (new NotificationService)->send($user, 'new_bid', 'New bid received', 'Someone bid on your job.');

        $this->assertNull($result);
        $this->assertDatabaseMissing('notifications', ['user_id' => $user->id]);
        Queue::assertNothingPushed();
    }

    public function test_a_type_with_no_category_is_never_gated(): void
    {
        Queue::fake();

        // Every category disabled — an ungated type (a verification
        // outcome, here) must still go through regardless.
        $user = User::factory()->create(['notification_preferences' => [
            'bids' => false, 'shipment_updates' => false, 'messages' => false, 'new_job_matches' => false,
        ]]);

        $notification = (new NotificationService)->send($user, 'company_approved', 'Company verified', 'Congrats.');

        $this->assertNotNull($notification);
        $this->assertDatabaseHas('notifications', ['id' => $notification->id]);
    }
}
