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

    public function test_a_deleted_notification_is_a_no_op(): void
    {
        $gateway = $this->mock(PushGateway::class);
        $gateway->shouldNotReceive('send');

        (new SendPushNotificationJob(999999))->handle($gateway);
    }
}
