<?php

namespace Tests\Feature\Auth;

use App\Mail\CustomerOtpMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

/**
 * Customer signup (email + password, verified once via an emailed code)
 * and login (Phase 11 — replaces the phone+SMS-OTP flow Customer
 * originally shared with Transporter Company; see OtpAuthTest for that).
 */
class CustomerAuthTest extends TestCase
{
    use RefreshDatabase;

    private function registerPayload(array $overrides = []): array
    {
        return array_merge([
            'full_name' => 'Amina Hassan',
            'email' => 'amina@example.com',
            'phone_number' => '0712345678',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ], $overrides);
    }

    public function test_registering_stores_no_plaintext_password_and_sends_an_email_code(): void
    {
        Mail::fake();

        $this->postJson('/api/auth/customer/register', $this->registerPayload())->assertOk();

        Mail::assertSent(CustomerOtpMail::class, fn ($mail) => $mail->hasTo('amina@example.com'));

        $pending = Cache::get('customer_registration:amina@example.com');
        $this->assertIsArray($pending);
        $this->assertNotSame('password123', $pending['password_hash']);
        $this->assertTrue(Hash::check('password123', $pending['password_hash']));
        $this->assertDatabaseMissing('users', ['email' => 'amina@example.com']);
    }

    public function test_verifying_the_code_creates_the_account_and_issues_a_token(): void
    {
        Mail::fake();
        $this->postJson('/api/auth/customer/register', $this->registerPayload(['company_name' => 'Amina Textiles']))->assertOk();
        $code = Cache::get('email_otp:amina@example.com:code')['code'];

        $response = $this->postJson('/api/auth/customer/register/verify', [
            'email' => 'amina@example.com',
            'code' => $code,
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.account_type', 'customer')
            ->assertJsonPath('user.full_name', 'Amina Hassan')
            ->assertJsonPath('user.email', 'amina@example.com')
            ->assertJsonPath('user.company_name', 'Amina Textiles')
            ->assertJsonStructure(['token']);

        $user = User::where('email', 'amina@example.com')->first();
        $this->assertNotNull($user);
        $this->assertSame('+255712345678', $user->phone_number);
        $this->assertNotNull($user->email_verified_at);
        $this->assertTrue(Hash::check('password123', $user->password_hash));
        // The pending cache entry is consumed, not left behind.
        $this->assertNull(Cache::get('customer_registration:amina@example.com'));
    }

    public function test_cannot_verify_with_the_wrong_code(): void
    {
        Mail::fake();
        $this->postJson('/api/auth/customer/register', $this->registerPayload())->assertOk();

        $this->postJson('/api/auth/customer/register/verify', [
            'email' => 'amina@example.com',
            'code' => '000000',
        ])->assertUnprocessable()->assertJsonValidationErrors('code');

        $this->assertDatabaseMissing('users', ['email' => 'amina@example.com']);
    }

    public function test_cannot_register_with_an_email_already_in_use(): void
    {
        User::factory()->create(['email' => 'amina@example.com']);

        $this->postJson('/api/auth/customer/register', $this->registerPayload())
            ->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_cannot_register_with_a_phone_number_already_in_use(): void
    {
        Mail::fake();
        User::factory()->create(['phone_number' => '+255712345678']);

        $this->postJson('/api/auth/customer/register', $this->registerPayload())
            ->assertUnprocessable()->assertJsonValidationErrors('phone_number');
    }

    public function test_password_confirmation_must_match(): void
    {
        $this->postJson('/api/auth/customer/register', $this->registerPayload(['password_confirmation' => 'different']))
            ->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_a_verified_customer_can_log_in_with_email_and_password(): void
    {
        Mail::fake();
        $this->postJson('/api/auth/customer/register', $this->registerPayload())->assertOk();
        $code = Cache::get('email_otp:amina@example.com:code')['code'];
        $this->postJson('/api/auth/customer/register/verify', ['email' => 'amina@example.com', 'code' => $code])->assertCreated();

        $this->postJson('/api/auth/customer/login', ['email' => 'amina@example.com', 'password' => 'password123'])
            ->assertOk()
            ->assertJsonPath('user.email', 'amina@example.com')
            ->assertJsonStructure(['token']);
    }

    public function test_login_fails_with_the_wrong_password(): void
    {
        Mail::fake();
        $this->postJson('/api/auth/customer/register', $this->registerPayload())->assertOk();
        $code = Cache::get('email_otp:amina@example.com:code')['code'];
        $this->postJson('/api/auth/customer/register/verify', ['email' => 'amina@example.com', 'code' => $code])->assertCreated();

        $this->postJson('/api/auth/customer/login', ['email' => 'amina@example.com', 'password' => 'wrong-password'])
            ->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_login_with_an_unknown_email_fails_the_same_way_as_a_wrong_password(): void
    {
        $this->postJson('/api/auth/customer/login', ['email' => 'nobody@example.com', 'password' => 'whatever123'])
            ->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_a_transporter_company_account_cannot_log_in_through_the_customer_endpoint(): void
    {
        $company = User::factory()->transporterCompany()->create(['email' => 'company@example.com']);
        $company->password_hash = Hash::make('somepassword');
        $company->save();

        $this->postJson('/api/auth/customer/login', ['email' => 'company@example.com', 'password' => 'somepassword'])
            ->assertUnprocessable()->assertJsonValidationErrors('email');
    }
}
