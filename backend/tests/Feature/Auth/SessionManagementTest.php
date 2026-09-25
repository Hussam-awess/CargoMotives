<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class SessionManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_lists_every_session_and_marks_the_current_one(): void
    {
        $user = User::factory()->create();
        $current = $user->createToken('Android device');
        $user->createToken('iOS device');

        $response = $this->withToken($current->plainTextToken)
            ->getJson('/api/auth/sessions')
            ->assertOk()
            ->assertJsonCount(2, 'data');

        $sessions = collect($response->json('data'))->keyBy('device_name');
        $this->assertTrue($sessions['Android device']['is_current']);
        $this->assertFalse($sessions['iOS device']['is_current']);
    }

    public function test_it_never_lists_another_users_sessions(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('Mine');
        User::factory()->create()->createToken('Someone else');

        $this->withToken($token->plainTextToken)
            ->getJson('/api/auth/sessions')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_another_device_can_be_signed_out(): void
    {
        $user = User::factory()->create();
        $current = $user->createToken('Current');
        $other = $user->createToken('Other');

        $this->withToken($current->plainTextToken)
            ->deleteJson("/api/auth/sessions/{$other->accessToken->id}")
            ->assertOk();

        $this->assertNull(PersonalAccessToken::find($other->accessToken->id));
        $this->assertNotNull(PersonalAccessToken::find($current->accessToken->id));
    }

    public function test_the_current_session_cannot_be_revoked_from_this_screen(): void
    {
        $user = User::factory()->create();
        $current = $user->createToken('Current');

        $this->withToken($current->plainTextToken)
            ->deleteJson("/api/auth/sessions/{$current->accessToken->id}")
            ->assertUnprocessable();

        $this->assertNotNull(PersonalAccessToken::find($current->accessToken->id));
    }

    public function test_another_users_session_cannot_be_revoked(): void
    {
        $user = User::factory()->create();
        $current = $user->createToken('Current');
        $victim = User::factory()->create()->createToken('Victim');

        $this->withToken($current->plainTextToken)
            ->deleteJson("/api/auth/sessions/{$victim->accessToken->id}")
            ->assertNotFound();

        $this->assertNotNull(PersonalAccessToken::find($victim->accessToken->id));
    }

    public function test_signing_out_everywhere_else_keeps_only_the_current_session(): void
    {
        $user = User::factory()->create();
        $current = $user->createToken('Current');
        $user->createToken('Old phone');
        $user->createToken('Tablet');

        $this->withToken($current->plainTextToken)
            ->deleteJson('/api/auth/sessions')
            ->assertOk()
            ->assertJsonPath('signed_out', 2);

        $this->assertSame([$current->accessToken->id], $user->tokens()->pluck('id')->all());
    }

    public function test_stale_sessions_are_pruned_but_recent_ones_kept(): void
    {
        config(['security.session_idle_days' => 90]);
        $user = User::factory()->create();

        $stale = $user->createToken('Lost phone')->accessToken;
        $stale->forceFill(['last_used_at' => now()->subDays(120)])->save();

        $neverUsed = $user->createToken('Never used')->accessToken;
        $neverUsed->forceFill(['created_at' => now()->subDays(100)])->save();

        $recent = $user->createToken('Daily phone')->accessToken;
        $recent->forceFill(['last_used_at' => now()->subDays(3)])->save();

        $this->artisan('auth:prune-stale-sessions')->assertSuccessful();

        $this->assertSame([$recent->id], $user->tokens()->pluck('id')->all());
    }

    public function test_login_names_the_session_after_the_device_and_sanitizes_it(): void
    {
        $user = User::factory()->withPassword('secret123')->create();

        $this->postJson('/api/auth/customer/login', [
            'email' => $user->email,
            'password' => 'secret123',
            'device_name' => '<b>Pixel</b> 6',
        ])->assertOk();

        $this->assertSame('Pixel 6', $user->tokens()->sole()->name);
    }
}
