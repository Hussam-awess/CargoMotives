<?php

namespace Tests\Unit\Services\Auth;

use App\Services\Auth\EmailOtpService;
use App\Services\Auth\OtpService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Tests\Concerns\CapturesOtpCodes;
use Tests\TestCase;

/**
 * One-time codes gate signup, password reset, credential changes and 2FA
 * login, so the cache must never hold a usable code — only a keyed hash
 * that's worthless without the app key.
 */
class OtpCodeHashingTest extends TestCase
{
    use CapturesOtpCodes;

    public function test_an_sms_code_is_stored_only_as_a_hash(): void
    {
        $this->fakeSms();

        app(OtpService::class)->issue('+255712345678');
        $code = $this->smsCodeSentTo('+255712345678');

        $stored = Cache::get('otp:+255712345678:code');
        $this->assertSame(['code_hash', 'attempts'], array_keys($stored));
        $this->assertNotContains($code, $stored);
        $this->assertTrue(app(OtpService::class)->verify('+255712345678', $code)->successful);
    }

    public function test_an_email_code_is_stored_only_as_a_hash(): void
    {
        Mail::fake();

        app(EmailOtpService::class)->issue('amina@example.com');
        $code = $this->emailCodeSentTo('amina@example.com');

        $stored = Cache::get('email_otp:amina@example.com:code');
        $this->assertSame(['code_hash', 'attempts'], array_keys($stored));
        $this->assertNotContains($code, $stored);
        $this->assertTrue(app(EmailOtpService::class)->verify('amina@example.com', $code)->successful);
    }

    public function test_a_wrong_guess_keeps_only_the_hash(): void
    {
        $this->fakeSms();
        app(OtpService::class)->issue('+255712345678');
        $code = $this->smsCodeSentTo('+255712345678');
        $hash = Cache::get('otp:+255712345678:code')['code_hash'];

        $result = app(OtpService::class)->verify('+255712345678', $this->wrongCodeFor($code));

        $this->assertSame('invalid_code', $result->reason);
        $this->assertSame(['code_hash' => $hash, 'attempts' => 1], Cache::get('otp:+255712345678:code'));
    }

    public function test_a_hash_copied_to_another_number_does_not_verify_there(): void
    {
        $this->fakeSms();
        app(OtpService::class)->issue('+255712345678');
        $code = $this->smsCodeSentTo('+255712345678');

        Cache::put('otp:+255799999999:code', Cache::get('otp:+255712345678:code'), 300);

        $this->assertSame('invalid_code', app(OtpService::class)->verify('+255799999999', $code)->reason);
    }

    public function test_a_plaintext_entry_from_before_hashing_counts_as_expired(): void
    {
        Cache::put('otp:+255712345678:code', ['code' => '123456', 'attempts' => 0], 300);
        Cache::put('email_otp:amina@example.com:code', ['code' => '123456', 'attempts' => 0], 300);

        $this->assertSame('expired_or_not_requested', app(OtpService::class)->verify('+255712345678', '123456')->reason);
        $this->assertSame('expired_or_not_requested', app(EmailOtpService::class)->verify('amina@example.com', '123456')->reason);
    }
}
