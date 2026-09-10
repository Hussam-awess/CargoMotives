<?php

namespace Tests\Feature\Messaging;

use App\Models\SupportMessage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * A user's standalone Support thread with Admin (Phase 10.15) — distinct
 * from MessageControllerTest's per-job thread. Always the caller's own
 * thread; see SupportMessageController's docblock for why there's no
 * participant check to test here (unlike the per-job Message model).
 */
class SupportMessageControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_send_a_message_into_their_own_thread(): void
    {
        $customer = User::factory()->create();

        $this->actingAs($customer)
            ->postJson('/api/support-messages', ['body' => 'How do I change my email?'])
            ->assertCreated()
            ->assertJsonPath('data.body', 'How do I change my email?')
            ->assertJsonPath('data.is_mine', true);
    }

    public function test_a_user_sees_only_their_own_thread(): void
    {
        $customer = User::factory()->create();
        $other = User::factory()->create();
        SupportMessage::factory()->create(['user_id' => $customer->id, 'body' => 'mine']);
        SupportMessage::factory()->create(['user_id' => $other->id, 'body' => 'not mine']);

        $response = $this->actingAs($customer)->getJson('/api/support-messages')->assertOk();

        $bodies = collect($response->json('data'))->pluck('body')->all();
        $this->assertSame(['mine'], $bodies);
    }

    public function test_an_admins_message_shows_as_not_mine_to_the_user(): void
    {
        $customer = User::factory()->create();
        $admin = User::factory()->admin()->create();
        SupportMessage::factory()->fromAdmin()->create(['user_id' => $customer->id, 'admin_id' => $admin->id, 'body' => 'Hi, how can we help?']);

        $response = $this->actingAs($customer)->getJson('/api/support-messages')->assertOk();

        $response->assertJsonPath('data.0.is_mine', false)->assertJsonPath('data.0.body', 'Hi, how can we help?');
    }

    public function test_messages_are_returned_in_chronological_order(): void
    {
        $customer = User::factory()->create();
        $first = SupportMessage::factory()->create(['user_id' => $customer->id, 'created_at' => now()->subMinutes(5)]);
        $second = SupportMessage::factory()->create(['user_id' => $customer->id, 'created_at' => now()]);

        $response = $this->actingAs($customer)->getJson('/api/support-messages');

        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertSame([$first->id, $second->id], $ids);
    }

    public function test_a_message_body_cannot_be_empty(): void
    {
        $customer = User::factory()->create();

        $this->actingAs($customer)
            ->postJson('/api/support-messages', ['body' => ''])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('body');
    }

    public function test_an_unauthenticated_request_is_rejected(): void
    {
        $this->getJson('/api/support-messages')->assertUnauthorized();
        $this->postJson('/api/support-messages', ['body' => 'hi'])->assertUnauthorized();
    }
}
