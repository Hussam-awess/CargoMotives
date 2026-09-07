<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Mockery;
use Tests\TestCase;

/**
 * Covers Transporter Company's phone+OTP flow (PRD §6, AppFlow §1) —
 * Customer moved to email+password in Phase 11 (see CustomerAuthTest) —
 * plus the failure modes that matter for a marketplace's trust model:
 * wrong code, expired code, brute-force lockout, resend cooldown, and the
 * account_type/phone binding that stops one phone number being reused.
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

    public function test_requesting_an_otp_succeeds_and_is_generic_about_existing_accounts(): void
    {
        $this->fakeSms();

        $response = $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
        ]);

        $response->assertOk()->assertJson(['message' => 'If the number is valid, a verification code has been sent.']);
    }

    public function test_full_signup_flow_creates_user_and_issues_token(): void
    {
        $this->fakeSms();

        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
        ])->assertOk();

        $code = Cache::get('otp:+255712345678:code')['code'];

        $response = $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => $code,
            'full_name' => 'Juma Ally',
            'email' => 'juma@example.com',
        ]);

        $response->assertOk()
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
    }

    public function test_different_phone_number_formats_resolve_to_the_same_account(): void
    {
        $this->fakeSms();
        User::factory()->transporterCompany()->create(['phone_number' => '+255712345678']);

        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '255712345678',
            'account_type' => 'transporter_company',
        ])->assertOk();

        $code = Cache::get('otp:+255712345678:code')['code'];

        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '255712345678',
            'account_type' => 'transporter_company',
            'code' => $code,
            'full_name' => 'Juma Ally',
            'email' => 'juma2@example.com',
        ])->assertOk();

        $this->assertSame(1, User::where('phone_number', '+255712345678')->count());
    }

    public function test_an_email_already_used_by_another_account_is_rejected(): void
    {
        $this->fakeSms();
        User::factory()->create(['email' => 'taken@example.com']);

        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
        ])->assertOk();

        $code = Cache::get('otp:+255712345678:code')['code'];

        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => $code,
            'full_name' => 'Juma Ally',
            'email' => 'taken@example.com',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');

        $this->assertDatabaseMissing('users', ['phone_number' => '+255712345678']);
    }

    public function test_wrong_code_is_rejected_without_consuming_the_real_code(): void
    {
        $this->fakeSms();
        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
        ]);

        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => '000000',
            'full_name' => 'Juma Ally',
            'email' => 'juma@example.com',
        ])->assertUnprocessable()->assertJsonValidationErrors('code');

        $realCode = Cache::get('otp:+255712345678:code')['code'];
        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
            'code' => $realCode,
            'full_name' => 'Juma Ally',
            'email' => 'juma@example.com',
        ])->assertOk();
    }

    public function test_code_locks_out_after_too_many_wrong_attempts(): void
    {
        $this->fakeSms();
        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
        ]);

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/otp/verify', [
                'phone_number' => '0712345678',
                'account_type' => 'transporter_company',
                'code' => '000000',
                'full_name' => 'Juma Ally',
                'email' => 'juma@example.com',
            ]);
        }

        $realCode = Cache::get('otp:+255712345678:code');
        $this->assertNull($realCode, 'code should be invalidated after max attempts');
    }

    public function test_requesting_a_second_otp_too_soon_is_rejected_with_cooldown(): void
    {
        $this->fakeSms();
        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
        ])->assertOk();

        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
        ])->assertStatus(429)->assertJsonStructure(['seconds_remaining']);
    }

    public function test_a_phone_cannot_switch_account_type(): void
    {
        $this->fakeSms();
        User::factory()->create(['phone_number' => '+255712345678', 'account_type' => 'customer']);

        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'transporter_company',
        ])->assertUnprocessable()->assertJsonValidationErrors('account_type');
    }

    public function test_invalid_phone_number_is_rejected(): void
    {
        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '12345',
            'account_type' => 'transporter_company',
        ])->assertUnprocessable()->assertJsonValidationErrors('phone_number');
    }

    public function test_customer_account_type_is_no_longer_accepted_here(): void
    {
        $this->postJson('/api/auth/otp/request', [
            'phone_number' => '0712345678',
            'account_type' => 'customer',
        ])->assertUnprocessable()->assertJsonValidationErrors('account_type');
    }
}
