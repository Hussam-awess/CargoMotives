<?php

namespace Tests\Feature\Auth;

use App\Mail\CustomerOtpMail;
use App\Models\User;
use App\Services\Auth\EmailOtpService;
use App\Services\Auth\OtpService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Tests\Concerns\CapturesOtpCodes;
use Tests\TestCase;

/**
 * Phase 10.16: full_name updates immediately; email/phone (login
 * credentials) require confirming a code sent to the *new* value first.
 * The email/phone flows reuse EmailOtpService/OtpService directly (no new
 * cache shape), so the confirm tests issue a code through those services
 * and read it from the sent email/SMS — the cache holds only its hash.
 */
class ProfileChangeTest extends TestCase
{
    use CapturesOtpCodes;
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
        $user = User::factory()->withPassword('password123')->create(['email' => 'old@example.com']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/request-change', ['new_email' => 'new@example.com', 'current_password' => 'password123'])
            ->assertOk();

        $this->assertSame('old@example.com', $user->fresh()->email);
        Mail::assertSent(CustomerOtpMail::class);
    }

    public function test_requesting_an_email_change_to_an_address_already_in_use_is_rejected(): void
    {
        User::factory()->create(['email' => 'taken@example.com']);
        $user = User::factory()->withPassword('password123')->create(['email' => 'mine@example.com']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/request-change', ['new_email' => 'taken@example.com', 'current_password' => 'password123'])
            ->assertUnprocessable();
    }

    public function test_requesting_an_email_change_with_the_wrong_current_password_is_rejected(): void
    {
        Mail::fake();
        $user = User::factory()->withPassword('password123')->create(['email' => 'old@example.com']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/request-change', ['new_email' => 'new@example.com', 'current_password' => 'wrong-password'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('current_password');

        Mail::assertNotSent(CustomerOtpMail::class);
    }

    public function test_confirming_an_email_change_with_the_right_code_applies_it(): void
    {
        Mail::fake();
        $user = User::factory()->create(['email' => 'old@example.com']);
        app(EmailOtpService::class)->issue('new@example.com');

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/confirm-change', ['new_email' => 'new@example.com', 'code' => $this->emailCodeSentTo('new@example.com')])
            ->assertOk()
            ->assertJsonPath('data.email', 'new@example.com');

        $this->assertSame('new@example.com', $user->fresh()->email);
    }

    public function test_confirming_an_email_change_with_the_wrong_code_does_not_apply_it(): void
    {
        Mail::fake();
        $user = User::factory()->create(['email' => 'old@example.com']);
        app(EmailOtpService::class)->issue('new@example.com');
        $wrongCode = $this->wrongCodeFor($this->emailCodeSentTo('new@example.com'));

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email/confirm-change', ['new_email' => 'new@example.com', 'code' => $wrongCode])
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
        $user = User::factory()->withPassword('password123')->create(['phone_number' => '+255700111000']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone/request-change', ['new_phone' => '0712345678', 'current_password' => 'password123'])
            ->assertOk();

        $this->assertSame('+255700111000', $user->fresh()->phone_number);
    }

    public function test_requesting_a_phone_change_to_a_number_already_in_use_is_rejected(): void
    {
        User::factory()->create(['phone_number' => '+255712345678']);
        $user = User::factory()->withPassword('password123')->create(['phone_number' => '+255700111000']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone/request-change', ['new_phone' => '0712345678', 'current_password' => 'password123'])
            ->assertUnprocessable();
    }

    public function test_requesting_a_phone_change_with_the_wrong_current_password_is_rejected(): void
    {
        $user = User::factory()->withPassword('password123')->create(['phone_number' => '+255700111000']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone/request-change', ['new_phone' => '0712345678', 'current_password' => 'wrong-password'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('current_password');

        $this->assertSame('+255700111000', $user->fresh()->phone_number);
    }

    public function test_confirming_a_phone_change_with_the_right_code_applies_the_normalized_number(): void
    {
        $this->fakeSms();
        $user = User::factory()->create(['phone_number' => '+255700111000']);
        app(OtpService::class)->issue('+255712345678');

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone/confirm-change', ['new_phone' => '0712345678', 'code' => $this->smsCodeSentTo('+255712345678')])
            ->assertOk()
            ->assertJsonPath('data.phone_number', '+255712345678');

        $this->assertSame('+255712345678', $user->fresh()->phone_number);
    }

    public function test_an_unauthenticated_request_is_rejected(): void
    {
        $this->postJson('/api/auth/profile/name', ['full_name' => 'X'])->assertUnauthorized();
        $this->postJson('/api/auth/profile/email/request-change', ['new_email' => 'x@example.com'])->assertUnauthorized();
    }

    public function test_a_customer_can_update_their_phone_number_immediately_with_no_code(): void
    {
        $user = User::factory()->create(['account_type' => 'customer', 'phone_number' => '+255700111000']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone', ['phone_number' => '0712345678'])
            ->assertOk()
            ->assertJsonPath('data.phone_number', '+255712345678');

        $this->assertSame('+255712345678', $user->fresh()->phone_number);
    }

    public function test_a_transporter_company_cannot_use_the_plain_phone_endpoint_since_its_their_credential(): void
    {
        $user = User::factory()->transporterCompany()->create(['phone_number' => '+255700111000']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone', ['phone_number' => '0712345678'])
            ->assertUnprocessable();

        $this->assertSame('+255700111000', $user->fresh()->phone_number);
    }

    public function test_a_transporter_company_can_update_their_email_immediately_with_no_code(): void
    {
        $user = User::factory()->transporterCompany()->create(['email' => 'old@example.com']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email', ['email' => 'new@example.com'])
            ->assertOk()
            ->assertJsonPath('data.email', 'new@example.com');

        $this->assertSame('new@example.com', $user->fresh()->email);
    }

    public function test_a_customer_cannot_use_the_plain_email_endpoint_since_its_their_credential(): void
    {
        $user = User::factory()->create(['account_type' => 'customer', 'email' => 'old@example.com']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/email', ['email' => 'new@example.com'])
            ->assertUnprocessable();

        $this->assertSame('old@example.com', $user->fresh()->email);
    }

    public function test_updating_the_phone_number_to_one_already_in_use_is_rejected(): void
    {
        User::factory()->create(['phone_number' => '+255712345678']);
        $user = User::factory()->create(['account_type' => 'customer', 'phone_number' => '+255700111000']);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/phone', ['phone_number' => '0712345678'])
            ->assertUnprocessable();
    }

    public function test_a_user_can_upload_a_profile_avatar(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();

        $response = $this->actingAs($user)
            ->post('/api/auth/profile/avatar', ['avatar' => UploadedFile::fake()->create('me.jpg', 100, 'image/jpeg')])
            ->assertOk();

        $this->assertNotNull($user->fresh()->avatar_url);
        $this->assertNotNull($response->json('data.avatar_url'));
    }

    public function test_a_non_image_avatar_is_rejected(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->post('/api/auth/profile/avatar', ['avatar' => UploadedFile::fake()->create('me.pdf', 100)])
            ->assertUnprocessable();
    }

    public function test_a_customer_can_update_their_business_identity(): void
    {
        Storage::fake('local');
        $user = User::factory()->create(['account_type' => 'customer', 'company_name' => 'Old Co']);

        $response = $this->actingAs($user)
            ->post('/api/auth/profile/business', [
                'company_name' => 'New Co',
                'logo' => UploadedFile::fake()->create('logo.jpg', 100, 'image/jpeg'),
            ])
            ->assertOk()
            ->assertJsonPath('data.company_name', 'New Co');

        $this->assertNotNull($response->json('data.company_logo_url'));
        $this->assertSame('New Co', $user->fresh()->company_name);
        $this->assertNotNull($user->fresh()->company_logo_url);
    }

    public function test_a_transporter_company_cannot_update_business_identity(): void
    {
        $user = User::factory()->transporterCompany()->create();

        $this->actingAs($user)
            ->postJson('/api/auth/profile/business', ['company_name' => 'New Co'])
            ->assertUnprocessable();
    }

    public function test_service_notifications_default_on_and_opt_in_ones_default_off(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('data.notification_preferences', [
                'bids' => true,
                'shipment_updates' => true,
                'messages' => true,
                'new_job_matches' => true,
                'sms_alerts' => false,
                'promotions' => false,
            ]);
    }

    public function test_sms_alerts_and_promotions_can_be_opted_into(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->postJson('/api/auth/profile/notification-preferences', ['sms_alerts' => true, 'promotions' => true])
            ->assertOk()
            ->assertJsonPath('data.notification_preferences.sms_alerts', true)
            ->assertJsonPath('data.notification_preferences.promotions', true);
    }

    public function test_a_notification_preference_can_be_turned_off(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->postJson('/api/auth/profile/notification-preferences', ['bids' => false])
            ->assertOk()
            ->assertJsonPath('data.notification_preferences.bids', false)
            ->assertJsonPath('data.notification_preferences.messages', true);

        $this->assertSame(['bids' => false], $user->fresh()->notification_preferences);
    }

    public function test_updating_one_preference_does_not_reset_another(): void
    {
        $user = User::factory()->create(['notification_preferences' => ['bids' => false]]);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/notification-preferences', ['messages' => false])
            ->assertOk();

        $this->assertSame(
            ['bids' => false, 'messages' => false],
            $user->fresh()->notification_preferences,
        );
    }
}
