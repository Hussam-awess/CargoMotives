<?php

namespace App\Services\Auth;

use App\Services\Sms\SmsGateway;
use App\Support\Pii;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Issues and verifies phone-number OTP codes.
 *
 * Deliberately backed by the cache (Redis in every real environment — see
 * config/cache.php / .env's CACHE_STORE) rather than a database table: an
 * OTP is short-lived, high-write, and disposable, which is exactly the data
 * shape Redis suits and Postgres doesn't need to carry (the Backend Schema's
 * table list has no OTP table for this reason).
 *
 * Only an HMAC of the code is stored (see hashCode()), never the code
 * itself, so read access to Redis alone doesn't hand out live codes. The
 * plaintext exists only in the outgoing SMS — which is also the only place
 * tests read it from (Tests\Concerns\CapturesOtpCodes).
 *
 * Failure points and how to trace them:
 *  - SMS send fails/times out: issue() still returns normally (the code is
 *    stored regardless) — per the TRD's graceful-degradation principle, a
 *    failed SMS never blocks the flow outright. Check storage/logs for the
 *    SmsSendResult's error (logged by the caller, not here) and, in local
 *    dev with SMS_DRIVER=log, the code itself is in the log line.
 *  - "Cache::get returns null" on verify: either the code expired
 *    (ttl_seconds) or was never requested for that (normalized) phone
 *    number — verify() reports this distinctly as 'expired_or_not_requested'.
 *  - Wrong code repeatedly: locks out after max_attempts, reported as
 *    'too_many_attempts', requiring a fresh issue().
 */
class OtpService
{
    public function __construct(private readonly SmsGateway $sms) {}

    /**
     * @throws OtpCooldownException if requested again before the cooldown elapses
     */
    public function issue(string $normalizedPhone): void
    {
        $cooldownKey = $this->cooldownKey($normalizedPhone);
        $availableAt = Cache::get($cooldownKey);

        // is_numeric, not is_int: the Redis cache store hands a stored
        // integer back as a numeric string, so an is_int check silently
        // never enforced this cooldown outside the array-cache tests.
        if (is_numeric($availableAt) && (int) $availableAt > now()->timestamp) {
            throw new OtpCooldownException((int) $availableAt - now()->timestamp);
        }

        $code = $this->generateCode();
        $ttl = now()->addSeconds(config('otp.ttl_seconds'));

        Cache::put($this->codeKey($normalizedPhone), ['code_hash' => $this->hashCode($normalizedPhone, $code), 'attempts' => 0], $ttl);

        $cooldownSeconds = config('otp.resend_cooldown_seconds');
        Cache::put($cooldownKey, now()->addSeconds($cooldownSeconds)->timestamp, $cooldownSeconds);

        $result = $this->sms->send($normalizedPhone, "Your Cargo Motives verification code is {$code}. It expires in ".(int) (config('otp.ttl_seconds') / 60).' minutes.');

        if (! $result->successful) {
            // Graceful degradation (TRD §5.3): the code is already stored and
            // usable, so a delivery failure doesn't block sign-in — it just
            // means the user won't receive it by SMS. Logged so a real
            // pattern of SMS failures is visible to whoever's watching logs.
            Log::warning('OTP SMS delivery failed', ['phone' => Pii::maskPhone($normalizedPhone), 'error' => $result->error]);
        }
    }

    public function verify(string $normalizedPhone, string $submittedCode): OtpVerificationResult
    {
        $key = $this->codeKey($normalizedPhone);
        $stored = Cache::get($key);

        // An entry without a code_hash is a plaintext code written before
        // codes were hashed — treated as expired (the user just requests a
        // new one) rather than erroring for the few minutes they outlive a
        // deploy.
        if (! is_array($stored) || ! is_string($stored['code_hash'] ?? null)) {
            return OtpVerificationResult::failure('expired_or_not_requested');
        }

        if ($stored['attempts'] >= config('otp.max_attempts')) {
            Cache::forget($key);

            return OtpVerificationResult::failure('too_many_attempts');
        }

        if (! hash_equals($stored['code_hash'], $this->hashCode($normalizedPhone, $submittedCode))) {
            $attempts = $stored['attempts'] + 1;

            // Lock out on the attempt that reaches the limit, not one call
            // later — otherwise "max_attempts" wrong guesses would still
            // report 'invalid_code' and a would-be attacker gets one extra
            // free guess before the lockout actually bites.
            if ($attempts >= config('otp.max_attempts')) {
                Cache::forget($key);

                return OtpVerificationResult::failure('too_many_attempts');
            }

            Cache::put($key, ['code_hash' => $stored['code_hash'], 'attempts' => $attempts], now()->addSeconds(config('otp.ttl_seconds')));

            return OtpVerificationResult::failure('invalid_code');
        }

        Cache::forget($key);

        return OtpVerificationResult::success();
    }

    private function generateCode(): string
    {
        $length = config('otp.code_length');
        $max = (10 ** $length) - 1;

        return str_pad((string) random_int(0, $max), $length, '0', STR_PAD_LEFT);
    }

    /**
     * Keyed with the app key: a plain SHA-256 of a 6-digit code falls to
     * trying all million codes, whereas this needs the key as well. The
     * phone number is part of the message so a hash observed for one number
     * says nothing about the same code issued to another.
     */
    private function hashCode(string $phone, string $code): string
    {
        return hash_hmac('sha256', "{$phone}|{$code}", config('app.key'));
    }

    private function codeKey(string $phone): string
    {
        return "otp:{$phone}:code";
    }

    private function cooldownKey(string $phone): string
    {
        return "otp:{$phone}:cooldown";
    }
}
