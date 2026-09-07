<?php

namespace App\Services\Auth;

use App\Mail\CustomerOtpMail;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * Issues and verifies email OTP codes for Customer registration — the
 * email-shaped counterpart to OtpService (phone/SMS, used by Transporter
 * Company). Kept as its own class rather than generalizing OtpService to
 * accept a delivery channel: the two are barely 80 lines each, genuinely
 * concrete integrations per two different channels (TRD's own "concrete,
 * not a premature abstraction" philosophy, same reasoning already applied
 * to GPS providers and mobile money), and OtpService is a heavily-tested
 * class from Phase 1 not worth touching for this.
 *
 * "Email OTP for now, SMS later" (explicit product decision): Customer
 * signup is verified by email until a real SMS provider is chosen, at
 * which point this could be swapped for phone-based verification the same
 * way OtpService already works for Transporter Company — this class is
 * deliberately structured identically to OtpService for exactly that
 * reason, even though nothing shares code between them today.
 */
class EmailOtpService
{
    /**
     * @throws OtpCooldownException if requested again before the cooldown elapses
     */
    public function issue(string $email): void
    {
        $cooldownKey = $this->cooldownKey($email);
        $availableAt = Cache::get($cooldownKey);

        if (is_int($availableAt) && $availableAt > now()->timestamp) {
            throw new OtpCooldownException($availableAt - now()->timestamp);
        }

        $code = $this->generateCode();
        $ttl = now()->addSeconds(config('otp.ttl_seconds'));

        Cache::put($this->codeKey($email), ['code' => $code, 'attempts' => 0], $ttl);

        $cooldownSeconds = config('otp.resend_cooldown_seconds');
        Cache::put($cooldownKey, now()->addSeconds($cooldownSeconds)->timestamp, $cooldownSeconds);

        try {
            Mail::to($email)->send(new CustomerOtpMail($code));
        } catch (\Throwable $e) {
            // Graceful degradation, matching OtpService's own SMS-failure
            // handling (TRD §5.3): the code is already stored and usable,
            // so a delivery failure doesn't block registration outright —
            // logged so a real pattern of failures is visible.
            Log::warning('Customer OTP email delivery failed', ['email' => $email, 'error' => $e->getMessage()]);
        }
    }

    public function verify(string $email, string $submittedCode): OtpVerificationResult
    {
        $key = $this->codeKey($email);
        $stored = Cache::get($key);

        if (! is_array($stored)) {
            return OtpVerificationResult::failure('expired_or_not_requested');
        }

        if ($stored['attempts'] >= config('otp.max_attempts')) {
            Cache::forget($key);

            return OtpVerificationResult::failure('too_many_attempts');
        }

        if (! hash_equals($stored['code'], $submittedCode)) {
            $attempts = $stored['attempts'] + 1;

            if ($attempts >= config('otp.max_attempts')) {
                Cache::forget($key);

                return OtpVerificationResult::failure('too_many_attempts');
            }

            Cache::put($key, ['code' => $stored['code'], 'attempts' => $attempts], now()->addSeconds(config('otp.ttl_seconds')));

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

    private function codeKey(string $email): string
    {
        return "email_otp:{$email}:code";
    }

    private function cooldownKey(string $email): string
    {
        return "email_otp:{$email}:cooldown";
    }
}
