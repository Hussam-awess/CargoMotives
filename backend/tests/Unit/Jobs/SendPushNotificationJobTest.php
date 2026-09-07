<?php

namespace Tests\Unit\Jobs;

use App\Jobs\SendPushNotificationJob;
use App\Models\DeviceToken;
use App\Models\Notification;
use App\Models\User;
use App\Services\Push\PushGateway;
use App\Services\Push\PushSendResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SendPushNotificationJobTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_does_nothing_when_the_user_has_no_registered_device(): void
    {
        $notification = Notification::factory()->create();

        $gateway = $this->mock(PushGateway::class);
        $gateway->shouldNotReceive('send');

        (new SendPushNotificationJob($notification->id))->handle($gateway);
    }

    public function test_it_sends_to_every_registered_token_and_marks_sent_via_fcm_on_success(): void
    {
        $user = User::factory()->create();
        $notification = Notification::factory()->create(['user_id' => $user->id, 'title' => 'Bid accepted', 'body' => 'Body text']);
        DeviceToken::factory()->create(['user_id' => $user->id, 'token' => 'good-token']);

        $gateway = $this->mock(PushGateway::class);
        $gateway->shouldReceive('send')
            ->once()
            ->with(['good-token'], 'Bid accepted', 'Body text', \Mockery::type('array'))
            ->andReturn(PushSendResult::success());

        (new SendPushNotificationJob($notification->id))->handle($gateway);

        $this->assertTrue($notification->fresh()->sent_via_fcm);
    }

    public function test_invalid_tokens_reported_by_the_gateway_are_deleted(): void
    {
        $user = User::factory()->create();
        $notification = Notification::factory()->create(['user_id' => $user->id]);
        DeviceToken::factory()->create(['user_id' => $user->id, 'token' => 'dead-token']);

        $gateway = $this->mock(PushGateway::class);
        $gateway->shouldReceive('send')->once()->andReturn(PushSendResult::success(['dead-token']));

        (new SendPushNotificationJob($notification->id))->handle($gateway);

        $this->assertDatabaseMissing('device_tokens', ['token' => 'dead-token']);
    }

    public function test_a_failed_send_does_not_mark_sent_via_fcm(): void
    {
        $user = User::factory()->create();
        $notification = Notification::factory()->create(['user_id' => $user->id]);
        DeviceToken::factory()->create(['user_id' => $user->id]);

        $gateway = $this->mock(PushGateway::class);
        $gateway->shouldReceive('send')->once()->andReturn(PushSendResult::failure('provider down'));

        (new SendPushNotificationJob($notification->id))->handle($gateway);

        $this->assertFalse($notification->fresh()->sent_via_fcm);
    }

    /**
     * A real live-verification bug (Phase 10.6 follow-up): FirebasePushDriver
     * used to discard invalidTokens whenever every token in a send failed
     * (the single-device case, where that one token happens to be dead) —
     * only a partial multi-device failure ever pruned anything. Caught by
     * sending a real invalid token through a real Firebase project, not by
     * this test — this test pins the fix so it can't quietly regress.
     */
    public function test_invalid_tokens_are_pruned_even_when_the_whole_send_failed(): void
    {
        $user = User::factory()->create();
        $notification = Notification::factory()->create(['user_id' => $user->id]);
        DeviceToken::factory()->create(['user_id' => $user->id, 'token' => 'the-only-and-dead-token']);

        $gateway = $this->mock(PushGateway::class);
        $gateway->shouldReceive('send')
            ->once()
            ->andReturn(PushSendResult::failure('Every device token in this send failed.', ['the-only-and-dead-token']));

        (new SendPushNotificationJob($notification->id))->handle($gateway);

        $this->assertDatabaseMissing('device_tokens', ['token' => 'the-only-and-dead-token']);
        $this->assertFalse($notification->fresh()->sent_via_fcm);
    }

    public function test_a_deleted_notification_is_a_no_op(): void
    {
        $gateway = $this->mock(PushGateway::class);
        $gateway->shouldNotReceive('send');

        (new SendPushNotificationJob(999999))->handle($gateway);
    }
}
