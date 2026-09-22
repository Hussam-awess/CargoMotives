<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

/**
 * Real, authenticated "change password" (ProfileController::changePassword)
 * — distinct from the forgot-password flow (OtpAuthTest/CustomerAuthTest),
 * which exists for when the caller does NOT know the current password.
 * Here they must prove they do, since a signed-in session alone isn't
 * strong enough proof for a change this sensitive (a hijacked/shared
 * session never had to know the password in the first place).
 */
class ChangePasswordTest extends TestCase
{
    use RefreshDatabase;

    public function test_changing_the_password_with_the_correct_current_password_succeeds(): void
    {
        $user = User::factory()->withPassword('old-password')->create();

        $this->actingAs($user)->postJson('/api/auth/profile/password', [
            'current_password' => 'old-password',
            'password' => 'new-password123',
            'password_confirmation' => 'new-password123',
        ])->assertOk();

        $this->assertTrue(Hash::check('new-password123', $user->fresh()->password_hash));
    }

    public function test_changing_the_password_with_the_wrong_current_password_is_rejected(): void
    {
        $user = User::factory()->withPassword('old-password')->create();

        $this->actingAs($user)
            ->postJson('/api/auth/profile/password', [
                'current_password' => 'not-the-password',
                'password' => 'new-password123',
                'password_confirmation' => 'new-password123',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('current_password');

        $this->assertTrue(Hash::check('old-password', $user->fresh()->password_hash));
    }

    public function test_a_mismatched_confirmation_is_rejected(): void
    {
        $user = User::factory()->withPassword('old-password')->create();

        $this->actingAs($user)
            ->postJson('/api/auth/profile/password', [
                'current_password' => 'old-password',
                'password' => 'new-password123',
                'password_confirmation' => 'does-not-match',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('password');
    }

    public function test_other_sessions_are_revoked_but_the_current_one_is_not(): void
    {
        $user = User::factory()->withPassword('old-password')->create();
        $otherToken = $user->createToken('other-device');
        $currentToken = $user->createToken('this-device');

        // Checked directly against the tokens table rather than via a
        // second authenticated round-trip: Sanctum's guard caches the
        // resolved user for the lifetime of the test's app container, so a
        // follow-up request reusing a *different* token in the same test
        // would just see that cached resolution, not re-authenticate.
        $this->withHeader('Authorization', "Bearer {$currentToken->plainTextToken}")
            ->postJson('/api/auth/profile/password', [
                'current_password' => 'old-password',
                'password' => 'new-password123',
                'password_confirmation' => 'new-password123',
            ])
            ->assertOk();

        $this->assertNull(PersonalAccessToken::find($otherToken->accessToken->id));
        $this->assertNotNull(PersonalAccessToken::find($currentToken->accessToken->id));
    }

    public function test_an_unauthenticated_request_is_rejected(): void
    {
        $this->postJson('/api/auth/profile/password', [
            'current_password' => 'x',
            'password' => 'new-password123',
            'password_confirmation' => 'new-password123',
        ])->assertUnauthorized();
    }
}
