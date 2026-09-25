<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\Concerns\CapturesOtpCodes;
use Tests\TestCase;

class TwoFactorTest extends TestCase
{
    use CapturesOtpCodes;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->fakeSms();
    }

    public function test_enabling_two_factor_requires_the_current_password(): void
    {
        $user = User::factory()->withPassword('secret123')->create();

        $this->actingAs($user)
            ->postJson('/api/auth/profile/two-factor', ['enabled' => true, 'current_password' => 'wrong'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('current_password');

        $this->assertFalse($user->fresh()->two_factor_enabled);

        $this->actingAs($user)
            ->postJson('/api/auth/profile/two-factor', ['enabled' => true, 'current_password' => 'secret123'])
            ->assertOk()
            ->assertJsonPath('data.two_factor_enabled', true);

        $this->assertTrue($user->fresh()->two_factor_enabled);
    }

    public function test_a_company_login_with_two_factor_returns_a_challenge_not_a_token(): void
    {
        $user = $this->companyWithTwoFactor();

        $response = $this->postJson('/api/auth/company/login', [
            'phone_number' => $this->localPhone($user),
            'password' => 'secret123',
            'device_name' => 'Android device',
        ])->assertOk()
            ->assertJsonPath('two_factor_required', true)
            ->assertJsonPath('channel', 'sms')
            ->assertJsonMissingPath('token');

        $this->assertSame(0, PersonalAccessToken::count());
        $this->assertStringEndsWith(substr($user->phone_number, -3), $response->json('destination'));
        $this->assertStringNotContainsString($user->phone_number, $response->json('destination'));
    }

    public function test_the_right_code_completes_a_company_login_and_names_the_session_after_the_device(): void
    {
        $user = $this->companyWithTwoFactor();
        $challenge = $this->startCompanyLogin($user);
        $code = $this->smsCodeSentTo($user->phone_number);

        $this->postJson('/api/auth/login/two-factor', ['challenge_token' => $challenge, 'code' => $code])
            ->assertOk()
            ->assertJsonStructure(['token', 'user' => ['id']]);

        $this->assertSame('Android device', $user->tokens()->sole()->name);
    }

    public function test_a_wrong_code_is_rejected_and_issues_no_token(): void
    {
        $user = $this->companyWithTwoFactor();
        $challenge = $this->startCompanyLogin($user);
        $code = $this->smsCodeSentTo($user->phone_number);

        $this->postJson('/api/auth/login/two-factor', ['challenge_token' => $challenge, 'code' => $this->wrongCodeFor($code)])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('code');

        $this->assertSame(0, PersonalAccessToken::count());
    }

    public function test_a_challenge_cannot_be_reused_after_it_succeeds(): void
    {
        $user = $this->companyWithTwoFactor();
        $challenge = $this->startCompanyLogin($user);
        $code = $this->smsCodeSentTo($user->phone_number);

        $this->postJson('/api/auth/login/two-factor', ['challenge_token' => $challenge, 'code' => $code])->assertOk();

        $this->postJson('/api/auth/login/two-factor', ['challenge_token' => $challenge, 'code' => $code])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('challenge_token');
    }

    public function test_an_unknown_challenge_token_is_rejected(): void
    {
        $this->postJson('/api/auth/login/two-factor', ['challenge_token' => str_repeat('a', 64), 'code' => '123456'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('challenge_token');
    }

    public function test_a_customer_login_with_two_factor_sends_the_code_by_email(): void
    {
        Mail::fake();

        $user = User::factory()->withPassword('secret123')->create();
        $user->forceFill(['two_factor_enabled' => true])->save();

        $challenge = $this->postJson('/api/auth/customer/login', ['email' => $user->email, 'password' => 'secret123'])
            ->assertOk()
            ->assertJsonPath('channel', 'email')
            ->json('challenge_token');

        $code = $this->emailCodeSentTo($user->email);

        $this->postJson('/api/auth/login/two-factor', ['challenge_token' => $challenge, 'code' => $code])
            ->assertOk()
            ->assertJsonStructure(['token']);
    }

    public function test_a_wrong_password_never_starts_a_challenge(): void
    {
        $user = $this->companyWithTwoFactor();

        $this->postJson('/api/auth/company/login', ['phone_number' => $this->localPhone($user), 'password' => 'wrong'])
            ->assertUnprocessable();

        $this->assertNull(Cache::get("otp:{$user->phone_number}:code"));
    }

    public function test_without_two_factor_login_still_returns_a_token_directly(): void
    {
        $user = User::factory()->transporterCompany()->withPassword('secret123')->create();

        $this->postJson('/api/auth/company/login', ['phone_number' => $this->localPhone($user), 'password' => 'secret123'])
            ->assertOk()
            ->assertJsonStructure(['token', 'user']);
    }

    public function test_an_sms_code_alone_cannot_sign_in_to_an_account_with_two_factor(): void
    {
        $user = $this->companyWithTwoFactor();

        $this->postJson('/api/auth/otp/request', [
            'phone_number' => $this->localPhone($user),
            'account_type' => 'transporter_company',
            'full_name' => 'Someone',
            'email' => 'someone@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
        ])->assertOk();

        $code = $this->smsCodeSentTo($user->phone_number);

        $this->postJson('/api/auth/otp/verify', [
            'phone_number' => $this->localPhone($user),
            'account_type' => 'transporter_company',
            'code' => $code,
        ])->assertUnprocessable();

        $this->assertSame(0, PersonalAccessToken::count());
    }

    private function companyWithTwoFactor(): User
    {
        $user = User::factory()->transporterCompany()->withPassword('secret123')->create();
        $user->forceFill(['two_factor_enabled' => true])->save();

        return $user;
    }

    private function startCompanyLogin(User $user): string
    {
        return $this->postJson('/api/auth/company/login', [
            'phone_number' => $this->localPhone($user),
            'password' => 'secret123',
            'device_name' => 'Android device',
        ])->json('challenge_token');
    }

    private function localPhone(User $user): string
    {
        return '0'.substr($user->phone_number, -9);
    }
}
