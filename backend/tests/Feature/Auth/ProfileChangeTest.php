<?php

namespace Tests\Feature\Auth;

use App\Mail\CustomerOtpMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

/**
 * Phase 10.16: full_name updates immediately; email/phone (login
 * credentials) require confirming a code sent to the *new* value first.
 * The email/phone flows reuse EmailOtpService/OtpService directly (no new
 * cache shape), so these tests read the code straight out of the cache
 * the same way CustomerAuthController's own tests already do, rather than
 * re-deriving the key format here.
 */
class ProfileChangeTest extends TestCase
{
    use RefreshDatabase;

    public function test_full_name_updates_immediately(): void
    {
        $user = User::factory()->create(['full_name' => 'Old Name']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/name', ['full_name' => 'New Name'])
            ->assertOk()
            ->assertJsonPath('data.full_name', 'New Name');

        $this->assertSame('New Name', $user->fresh()->full_name);
    }

    public function test_a_blank_name_is_rejected(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/auth/profile/name', ['full_name' => ''])->assertUnprocessable();
    }

    public function test_requesting_an_email_change_sends_a_code_and_does_not_change_the_email_yet(): void
    {
        Mail::fake();
        $user = User::factory()->create(['email' => 'old@example.com']);

        $this->actingAs($user)->postJson('/api/auth/profile/email/request-change', ['new_email' => 'new@example.com'])->assertOk();

        $this->assertSame('old@example.com', $user->fresh()->email);
        Mail::assertSent(CustomerOtpMail::class);
    }

    public function test_requesting_an_email_change_to_an_address_already_in_use_is_rejected(): void
    {
        User::factory()->create(['email' => 'taken@example.com']);
        $user = User::factory()->create(['email' => 'mine@example.com']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/request-change', ['new_email' => 'taken@example.com'])
            ->assertUnprocessable();
    }

    public function test_confirming_an_email_change_with_the_right_code_applies_it(): void
    {
        $user = User::factory()->create(['email' => 'old@example.com']);
        Cache::put('email_otp:new@example.com:code', ['code' => '123456', 'attempts' => 0], now()->addMinutes(5));

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/confirm-change', ['new_email' => 'new@example.com', 'code' => '123456'])
            ->assertOk()
            ->assertJsonPath('data.email', 'new@example.com');

        $this->assertSame('new@example.com', $user->fresh()->email);
    }

    public function test_confirming_an_email_change_with_the_wrong_code_does_not_apply_it(): void
    {
        $user = User::factory()->create(['email' => 'old@example.com']);
        Cache::put('email_otp:new@example.com:code', ['code' => '123456', 'attempts' => 0], now()->addMinutes(5));

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/confirm-change', ['new_email' => 'new@example.com', 'code' => '000000'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('code');

        $this->assertSame('old@example.com', $user->fresh()->email);
    }

    public function test_confirming_an_email_change_with_no_code_ever_requested_fails(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/confirm-change', ['new_email' => 'never-requested@example.com', 'code' => '123456'])
            ->assertUnprocessable();
    }

    public function test_requesting_a_phone_change_sends_a_code_and_does_not_change_the_phone_yet(): void
    {
        $user = User::factory()->create(['phone_number' => '+255700111000']);

        $this->actingAs($user)->postJson('/api/auth/profile/phone/request-change', ['new_phone' => '0712345678'])->assertOk();

        $this->assertSame('+255700111000', $user->fresh()->phone_number);
    }

    public function test_requesting_a_phone_change_to_a_number_already_in_use_is_rejected(): void
    {
        User::factory()->create(['phone_number' => '+255712345678']);
        $user = User::factory()->create(['phone_number' => '+255700111000']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone/request-change', ['new_phone' => '0712345678'])
            ->assertUnprocessable();
    }

    public function test_confirming_a_phone_change_with_the_right_code_applies_the_normalized_number(): void
    {
        $user = User::factory()->create(['phone_number' => '+255700111000']);
        Cache::put('otp:+255712345678:code', ['code' => '654321', 'attempts' => 0], now()->addMinutes(5));

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone/confirm-change', ['new_phone' => '0712345678', 'code' => '654321'])
            ->assertOk()
            ->assertJsonPath('data.phone_number', '+255712345678');

        $this->assertSame('+255712345678', $user->fresh()->phone_number);
    }

    public function test_an_unauthenticated_request_is_rejected(): void
    {
        $this->postJson('/api/auth/profile/name', ['full_name' => 'X'])->assertUnauthorized();
        $this->postJson('/api/auth/profile/email/request-change', ['new_email' => 'x@example.com'])->assertUnauthorized();
    }
}
