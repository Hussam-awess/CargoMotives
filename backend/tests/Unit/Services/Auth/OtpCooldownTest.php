<?php

namespace Tests\Unit\Services\Auth;

use App\Services\Auth\EmailOtpService;
use App\Services\Auth\OtpCooldownException;
use App\Services\Auth\OtpService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

/**
 * Regression: the Redis cache store returns a stored integer as a numeric
 * string, and the cooldown check used is_int() — so the resend cooldown was
 * never enforced in any real environment, only under the array-cache
 * tests. Found by a live check against the dev server (Redis).
 */
class OtpCooldownTest extends TestCase
{
    public function test_the_sms_cooldown_holds_when_the_cache_returns_a_numeric_string(): void
    {
        Cache::put('otp:+255712345678:cooldown', (string) now()->addSeconds(45)->timestamp, 60);

        $this->expectException(OtpCooldownException::class);

        app(OtpService::class)->issue('+255712345678');
    }

    public function test_the_email_cooldown_holds_when_the_cache_returns_a_numeric_string(): void
    {
        Mail::fake();
        Cache::put('email_otp:amina@example.com:cooldown', (string) now()->addSeconds(45)->timestamp, 60);

        $this->expectException(OtpCooldownException::class);

        app(EmailOtpService::class)->issue('amina@example.com');
    }

    public function test_an_elapsed_cooldown_allows_a_new_code(): void
    {
        Cache::put('otp:+255712345678:cooldown', (string) now()->subSecond()->timestamp, 60);

        app(OtpService::class)->issue('+255712345678');

        $this->assertIsArray(Cache::get('otp:+255712345678:code'));
    }
}
