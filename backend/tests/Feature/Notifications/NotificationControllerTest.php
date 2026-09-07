<?php

namespace Tests\Feature\Notifications;

use App\Models\DeviceToken;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * In-app notifications + FCM device token registration (Backend Schema
 * §2.18, AppFlow §3.1's bell icon). Plain REST + refresh-on-open (TRD §4).
 */
class NotificationControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_sees_only_their_own_notifications_newest_first(): void
    {
        $user = User::factory()->create();
        $stranger = User::factory()->create();

        $older = Notification::factory()->create(['user_id' => $user->id, 'created_at' => now()->subHour()]);
        $newer = Notification::factory()->create(['user_id' => $user->id, 'created_at' => now()]);
        Notification::factory()->create(['user_id' => $stranger->id]);

        $response = $this->actingAs($user)->getJson('/api/notifications')->assertOk();

        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertSame([$newer->id, $older->id], $ids);
    }

    public function test_unread_count_only_counts_this_users_unread_notifications(): void
    {
        $user = User::factory()->create();
        Notification::factory()->create(['user_id' => $user->id]);
        Notification::factory()->create(['user_id' => $user->id]);
        Notification::factory()->create(['user_id' => $user->id, 'read_at' => now()]);
        Notification::factory()->create(['user_id' => User::factory()->create()->id]);

        $this->actingAs($user)->getJson('/api/notifications/unread-count')
            ->assertOk()
            ->assertJson(['unread_count' => 2]);
    }

    public function test_marking_a_notification_read_sets_read_at(): void
    {
        $user = User::factory()->create();
        $notification = Notification::factory()->create(['user_id' => $user->id]);

        $this->actingAs($user)->postJson("/api/notifications/{$notification->id}/read")->assertOk();

        $this->assertNotNull($notification->fresh()->read_at);
    }

    public function test_a_user_cannot_mark_another_users_notification_read(): void
    {
        $notification = Notification::factory()->create();
        $stranger = User::factory()->create();

        $this->actingAs($stranger)->postJson("/api/notifications/{$notification->id}/read")->assertNotFound();
        $this->assertNull($notification->fresh()->read_at);
    }

    public function test_mark_all_read_only_touches_the_current_users_notifications(): void
    {
        $user = User::factory()->create();
        $mine = Notification::factory()->create(['user_id' => $user->id]);
        $someoneElses = Notification::factory()->create();

        $this->actingAs($user)->postJson('/api/notifications/read-all')->assertOk();

        $this->assertNotNull($mine->fresh()->read_at);
        $this->assertNull($someoneElses->fresh()->read_at);
    }

    public function test_registering_a_device_token_creates_it(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->postJson('/api/notifications/device-token', ['token' => 'fcm-token-123', 'platform' => 'android'])
            ->assertCreated();

        $this->assertDatabaseHas('device_tokens', ['user_id' => $user->id, 'token' => 'fcm-token-123', 'platform' => 'android']);
    }

    public function test_re_registering_the_same_token_under_a_different_account_moves_it(): void
    {
        $firstUser = User::factory()->create();
        $secondUser = User::factory()->create();
        DeviceToken::factory()->create(['user_id' => $firstUser->id, 'token' => 'shared-device-token']);

        $this->actingAs($secondUser)
            ->postJson('/api/notifications/device-token', ['token' => 'shared-device-token', 'platform' => 'ios'])
            ->assertCreated();

        $this->assertSame(1, DeviceToken::where('token', 'shared-device-token')->count());
        $this->assertDatabaseHas('device_tokens', ['token' => 'shared-device-token', 'user_id' => $secondUser->id]);
    }

    public function test_deleting_a_device_token_removes_it(): void
    {
        $user = User::factory()->create();
        DeviceToken::factory()->create(['user_id' => $user->id, 'token' => 'logging-out-token']);

        $this->actingAs($user)
            ->deleteJson('/api/notifications/device-token', ['token' => 'logging-out-token'])
            ->assertOk();

        $this->assertDatabaseMissing('device_tokens', ['token' => 'logging-out-token']);
    }
}
