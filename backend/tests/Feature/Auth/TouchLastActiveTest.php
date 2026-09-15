<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * TouchLastActive is bundled into the 'auth-active' middleware group
 * (bootstrap/app.php) rather than tested in isolation, since its only
 * observable effect is the side-effect it has on a real authenticated
 * request going through that exact group.
 */
class TouchLastActiveTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_authenticated_request_sets_last_active_at(): void
    {
        $user = User::factory()->create(['last_active_at' => null]);

        $this->actingAs($user)->getJson('/api/auth/me')->assertOk();

        $this->assertNotNull($user->fresh()->last_active_at);
    }

    public function test_it_does_not_rewrite_a_recent_timestamp_on_every_request(): void
    {
        $recent = now()->subMinutes(5);
        $user = User::factory()->create(['last_active_at' => $recent]);

        $this->actingAs($user)->getJson('/api/auth/me')->assertOk();

        $this->assertSame($recent->format('Y-m-d H:i:s'), $user->fresh()->last_active_at->format('Y-m-d H:i:s'));
    }

    public function test_it_refreshes_a_stale_timestamp(): void
    {
        $stale = now()->subHours(2);
        $user = User::factory()->create(['last_active_at' => $stale]);

        $this->actingAs($user)->getJson('/api/auth/me')->assertOk();

        $this->assertTrue($user->fresh()->last_active_at->greaterThan($stale));
    }
}
