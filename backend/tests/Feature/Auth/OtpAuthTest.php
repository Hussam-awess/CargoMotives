<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Mockery;
use Tests\TestCase;

/**
 * Covers Transporter Company's phone+OTP flow (PRD §6, AppFlow §1) —
 * Customer moved to email+password in Phase 11 (see CustomerAuthTest) —
 * plus the failure modes that matter for a marketplace's trust model:
 * wrong code, expired code, brute-force lockout, resend cooldown, and the
 * account_type/phone binding that stops one phone number being reused.
 *
 * Design-import restyle: full_name/email/password are collected at
 * request-time now (mirroring CustomerAuthController's pending-cache
 * pattern), not at verify-time — see AuthController's docblock.
 */
class OtpAuthTest extends TestCase
{
    use RefreshDatabase;

    private function fakeSms(): void
    {
        $sms = Mockery::mock(SmsGateway::class);
        $sms->shouldReceive('send')->andReturn(SmsSendResult::success());
        $this->app->instance(SmsGateway::class, $sms);
    }

    /**
     * @return array<string, mixed>
     */
    private function requestPayload(array $overrides = []): array
    {
        return array_merge([
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'full_name' => 'Juma Ally',
            'email' => 'juma@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ], $overrides);
    }

    public function test_requesting_an_otp_succeeds_and_is_generic_about_existing_accounts(): void
    {
        $this->fakeSms();

        $response = $this->postJson('/api/auth/otp/request', $this->requestPayload());

        $response->assertOk()->assertJson(['message' => 'If the number is valid, a verification code has been sent.']);
    }

    public function test_full_signup_flow_creates_user_and_issues_token(): void
    {
        $this->fakeSms();

        $this->postJson('/api/auth/otp/request', $this->requestPayload())->assertOk();

        $code = Cache::get('otp:+255712345678:code')['code'];

        $response = $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => $code,
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.phone_number', '+255712345678')
            ->assertJsonPath('user.account_type', 'transporter_company')
            ->assertJsonPath('user.full_name', 'Juma Ally')
            ->assertJsonPath('user.email', 'juma@example.com')
            ->assertJsonStructure(['token']);

        $this->assertDatabaseHas('users', [
            'phone_number' => '+255712345678',
            'account_type' => 'transporter_company',
            'full_name' => 'Juma Ally',
            'email' => 'juma@example.com',
        ]);

        $user = User::where('phone_number', '+255712345678')->first();
        $this->assertTrue(Hash::check('password123', $user->password_hash));
    }

    public function test_no_plaintext_password_is_ever_stored_before_verification(): void
    {
        $this->fakeSms();

        $this->postJson('/api/auth/otp/request', $this->requestPayload())->assertOk();

        $pending = Cache::get('transporter_registration:+255712345678');
        $this->assertIsArray($pending);
        $this->assertNotSame('password123', $pending['password_hash']);
        $this->assertTrue(Hash::check('password123', $pending['password_hash']));
    }

    /**
     * PhoneNumberNormalizer itself still accepts +255/255-prefixed and
     * bare-national shapes (PhoneNumberNormalizerTest covers that) — but as
     * of the phone-input hardening, the API boundary now only accepts one
     * shape (10 digits starting with "0"), so a 255-prefixed submission is
     * rejected here rather than silently normalized.
     */
    public function test_a_non_zero_prefixed_phone_number_is_rejected_at_the_api_boundary(): void
    {
        $this->fakeSms();

        $this->postJson('/api/auth/otp/request', $this->requestPayload([
            'phone_number' => '255712345678',
        ]))->assertUnprocessable()->assertJsonValidationErrors('phone_number');
    }

    public function test_an_email_already_used_by_another_account_is_rejected_at_request_time(): void
    {
        $this->fakeSms();
        User::factory()->create(['email' => 'taken@example.com']);

        $this->postJson('/api/auth/otp/request', $this->requestPayload(['email' => 'taken@example.com']))
            ->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_wrong_code_is_rejected_without_consuming_the_real_code(): void
    {
        $this->fakeSms();
        $this->postJson('/api/auth/otp/request', $this->requestPayload());

        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => '000000',
        ])->assertUnprocessable()->assertJsonValidationErrors('code');

        $realCode = Cache::get('otp:+255712345678:code')['code'];
        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => $realCode,
        ])->assertCreated();
    }

    public function test_code_locks_out_after_too_many_wrong_attempts(): void
    {
        $this->fakeSms();
        $this->postJson('/api/auth/otp/request', $this->requestPayload());

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/otp/verify', [
                'phone_number' => '0712345678',
                'account_type' => 'transporter_company',
                'code' => '000000',
            ]);
        }

        $realCode = Cache::get('otp:+255712345678:code');
        $this->assertNull($realCode, 'code should be invalidated after max attempts');
    }

    public function test_requesting_a_second_otp_too_soon_is_rejected_with_cooldown(): void
    {
        $this->fakeSms();
        $this->postJson('/api/auth/otp/request', $this->requestPayload())->assertOk();

        $this->postJson('/api/auth/otp/request', $this->requestPayload())
            ->assertStatus(429)->assertJsonStructure(['seconds_remaining']);
    }

    public function test_a_phone_cannot_switch_account_type(): void
    {
        $this->fakeSms();
        User::factory()->create(['phone_number' => '+255712345678', 'account_type' => 'customer']);

        $this->postJson('/api/auth/otp/request', $this->requestPayload())
            ->assertUnprocessable()->assertJsonValidationErrors('account_type');
    }

    public function test_invalid_phone_number_is_rejected(): void
    {
        $this->postJson('/api/auth/otp/request', $this->requestPayload(['phone_number' => '12345']))
            ->assertUnprocessable()->assertJsonValidationErrors('phone_number');
    }

    public function test_customer_account_type_is_no_longer_accepted_here(): void
    {
        $this->postJson('/api/auth/otp/request', $this->requestPayload(['account_type' => 'customer']))
            ->assertUnprocessable()->assertJsonValidationErrors('account_type');
    }

    public function test_mismatched_password_confirmation_is_rejected(): void
    {
        $this->postJson('/api/auth/otp/request', $this->requestPayload(['password_confirmation' => 'different']))
            ->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_verifying_without_a_prior_request_is_rejected(): void
    {
        $this->fakeSms();
        // A code that was never actually issued — verify() fails on the
        // OTP check itself before ever consulting the pending cache.
        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => '123456',
        ])->assertUnprocessable()->assertJsonValidationErrors('code');
    }

    public function test_a_transporter_company_can_log_in_with_phone_and_password(): void
    {
        $this->fakeSms();
        $this->postJson('/api/auth/otp/request', $this->requestPayload())->assertOk();
        $code = Cache::get('otp:+255712345678:code')['code'];
        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => $code,
        ])->assertCreated();

        $response = $this->postJson('/api/auth/company/login', [
            'phone_number' => '0712345678',
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.phone_number', '+255712345678')
            ->assertJsonStructure(['token']);
    }

    public function test_login_with_the_wrong_password_is_rejected(): void
    {
        $company = User::factory()->transporterCompany()->create(['phone_number' => '+255712345678']);
        $company->password_hash = Hash::make('correct-password');
        $company->save();

        $this->postJson('/api/auth/company/login', [
            'phone_number' => '0712345678',
            'password' => 'wrong-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('phone_number');
    }

    public function test_repeated_failed_logins_across_different_ips_still_lock_the_account(): void
    {
        $company = User::factory()->transporterCompany()->create(['phone_number' => '+255712345678']);
        $company->password_hash = Hash::make('correct-password');
        $company->save();

        // A different IP on every attempt so the per-route `throttle:*`
        // limiter (keyed on phone+IP, AppServiceProvider) never itself
        // trips — isolating that this lockout is LoginThrottle's own
        // identifier-only tracking, not the pre-existing rate limiter.
        for ($i = 0; $i < 5; $i++) {
            $this->withServerVariables(['REMOTE_ADDR' => "10.0.0.{$i}"])
                ->postJson('/api/auth/company/login', [
                    'phone_number' => '0712345678',
                    'password' => 'wrong-password',
                ])->assertUnprocessable();
        }

        // A brand-new IP would sail past the per-IP+phone rate limiter, but
        // LoginThrottle keys on the phone number alone and still blocks it
        // — even with the real password.
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.99'])
            ->postJson('/api/auth/company/login', [
                'phone_number' => '0712345678',
                'password' => 'correct-password',
            ])->assertStatus(429);
    }

    public function test_a_successful_login_clears_prior_failed_attempts(): void
    {
        $company = User::factory()->transporterCompany()->create(['phone_number' => '+255712345678']);
        $company->password_hash = Hash::make('correct-password');
        $company->save();

        $this->postJson('/api/auth/company/login', [
            'phone_number' => '0712345678',
            'password' => 'wrong-password',
        ])->assertUnprocessable();

        $this->postJson('/api/auth/company/login', [
            'phone_number' => '0712345678',
            'password' => 'correct-password',
        ])->assertOk();

        // Confirms the earlier failure isn't still silently counted toward
        // a future lockout window.
        $this->postJson('/api/auth/company/login', [
            'phone_number' => '0712345678',
            'password' => 'wrong-password',
        ])->assertUnprocessable()->assertJsonMissing(['seconds_remaining']);
    }

    public function test_login_with_an_unknown_phone_number_is_rejected(): void
    {
        $this->postJson('/api/auth/company/login', [
            'phone_number' => '0799999999',
            'password' => 'whatever123',
        ])->assertUnprocessable()->assertJsonValidationErrors('phone_number');
    }

    public function test_a_customer_cannot_log_in_via_the_company_endpoint(): void
    {
        $customer = User::factory()->create(['phone_number' => '+255712345678', 'account_type' => 'customer']);
        $customer->password_hash = Hash::make('password123');
        $customer->save();

        $this->postJson('/api/auth/company/login', [
            'phone_number' => '0712345678',
            'password' => 'password123',
        ])->assertUnprocessable()->assertJsonValidationErrors('phone_number');
    }

    public function test_requesting_a_password_reset_is_generic_about_existing_accounts(): void
    {
        $this->fakeSms();
        User::factory()->transporterCompany()->create(['phone_number' => '+255712345678']);

        $forKnown = $this->postJson('/api/auth/company/password/forgot', ['phone_number' => '0712345678']);
        $forUnknown = $this->postJson('/api/auth/company/password/forgot', ['phone_number' => '0799999999']);

        $forKnown->assertOk()->assertJson(['message' => 'If that number has an account, a reset code has been sent.']);
        $forUnknown->assertOk()->assertJson(['message' => 'If that number has an account, a reset code has been sent.']);
        // Only the known phone actually got a code — the unknown one never
        // triggers OtpService::issue() at all (nothing to verify() later).
        $this->assertNotNull(Cache::get('otp:+255712345678:code'));
        $this->assertNull(Cache::get('otp:+255799999999:code'));
    }

    public function test_full_password_reset_flow_changes_password_and_allows_login(): void
    {
        $this->fakeSms();
        User::factory()->transporterCompany()->create(['phone_number' => '+255712345678']);

        $this->postJson('/api/auth/company/password/forgot', ['phone_number' => '0712345678'])->assertOk();
        $code = Cache::get('otp:+255712345678:code')['code'];

        $this->postJson('/api/auth/company/password/reset', [
            'phone_number' => '0712345678',
            'code' => $code,
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ])->assertOk();

        $user = User::where('phone_number', '+255712345678')->first();
        $this->assertTrue(Hash::check('new-password-123', $user->password_hash));

        $this->postJson('/api/auth/company/login', [
            'phone_number' => '0712345678',
            'password' => 'new-password-123',
        ])->assertOk();
    }

    public function test_password_reset_revokes_existing_sessions(): void
    {
        $this->fakeSms();
        $user = User::factory()->transporterCompany()->create(['phone_number' => '+255712345678']);
        $token = $user->createToken('mobile-app')->plainTextToken;

        $this->postJson('/api/auth/company/password/forgot', ['phone_number' => '0712345678'])->assertOk();
        $code = Cache::get('otp:+255712345678:code')['code'];
        $this->postJson('/api/auth/company/password/reset', [
            'phone_number' => '0712345678',
            'code' => $code,
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ])->assertOk();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/auth/me')
            ->assertUnauthorized();
    }

    public function test_confirming_a_reset_with_the_wrong_code_is_rejected(): void
    {
        $this->fakeSms();
        User::factory()->transporterCompany()->create(['phone_number' => '+255712345678']);
        $this->postJson('/api/auth/company/password/forgot', ['phone_number' => '0712345678'])->assertOk();

        $this->postJson('/api/auth/company/password/reset', [
            'phone_number' => '0712345678',
            'code' => '000000',
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ])->assertUnprocessable()->assertJsonValidationErrors('code');
    }
}
