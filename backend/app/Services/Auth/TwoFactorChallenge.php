<?php

namespace App\Services\Auth;

use App\Models\User;
use App\Support\Pii;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * The second step of a login for an account with two_factor_enabled.
 *
 * After the password checks out, start() sends a one-time code over the
 * account's own channel — SMS for a Transporter Company (phone is its login
 * identity), email for a Customer — and hands back an opaque challenge
 * token instead of an access token. complete() exchanges challenge token +
 * code for the user. The challenge token alone is worthless (no code), and
 * the code alone is worthless (no challenge), so neither leaking by itself
 * grants access.
 *
 * Only a SHA-256 of the challenge token is stored, so a cache dump can't be
 * replayed. The code itself reuses OtpService/EmailOtpService, inheriting
 * their expiry, resend cooldown and max-attempts lockout unchanged.
 */
class TwoFactorChallenge
{
    private const PREFIX = 'two_factor_challenge:';

    public function __construct(
        private readonly OtpService $smsOtp,
        private readonly EmailOtpService $emailOtp,
    ) {}

    /**
     * @return array<string, mixed> the response body for the login endpoint
     */
    public function start(User $user, string $deviceName): array
    {
        $challengeToken = Str::random(64);

        Cache::put($this->key($challengeToken), [
            'user_id' => $user->id,
            'device_name' => $deviceName,
        ], now()->addSeconds(config('otp.ttl_seconds')));

        try {
            $this->sendCode($user);
        } catch (OtpCooldownException) {
            // A code sent moments ago (e.g. a double-tapped Log in) is
            // still valid — the user just enters that one.
        }

        return [
            'two_factor_required' => true,
            'challenge_token' => $challengeToken,
            'channel' => $this->usesEmail($user) ? 'email' : 'sms',
            'destination' => $this->usesEmail($user) ? Pii::maskEmail($user->email) : Pii::maskPhone($user->phone_number),
            'message' => 'Enter the verification code we just sent you.',
        ];
    }

    /**
     * @throws OtpCooldownException
     * @throws ValidationException when the challenge has expired
     */
    public function resend(string $challengeToken): void
    {
        $this->sendCode($this->pending($challengeToken)['user']);
    }

    /**
     * @return array{user: User, device_name: string}
     *
     * @throws ValidationException on an expired challenge or a wrong code
     */
    public function complete(string $challengeToken, string $code): array
    {
        $pending = $this->pending($challengeToken);
        $user = $pending['user'];

        $result = $this->usesEmail($user)
            ? $this->emailOtp->verify($user->email, $code)
            : $this->smsOtp->verify($user->phone_number, $code);

        if (! $result->successful) {
            throw ValidationException::withMessages(['code' => [match ($result->reason) {
                'invalid_code' => 'That code is incorrect.',
                'too_many_attempts' => 'Too many incorrect attempts. Request a new code.',
                default => 'That code has expired. Request a new one.',
            }]]);
        }

        Cache::forget($this->key($challengeToken));

        return ['user' => $user, 'device_name' => $pending['device_name']];
    }

    /**
     * @return array{user: User, device_name: string}
     */
    private function pending(string $challengeToken): array
    {
        $stored = Cache::get($this->key($challengeToken));
        $user = is_array($stored) ? User::find($stored['user_id']) : null;

        if ($user === null) {
            throw ValidationException::withMessages([
                'challenge_token' => ['Your sign-in attempt expired. Please log in again.'],
            ]);
        }

        return ['user' => $user, 'device_name' => DeviceName::sanitize($stored['device_name'] ?? null)];
    }

    /**
     * @throws OtpCooldownException
     */
    private function sendCode(User $user): void
    {
        $this->usesEmail($user)
            ? $this->emailOtp->issue($user->email)
            : $this->smsOtp->issue($user->phone_number);
    }

    private function usesEmail(User $user): bool
    {
        return $user->account_type === 'customer' && $user->email !== null;
    }

    private function key(string $challengeToken): string
    {
        return self::PREFIX.hash('sha256', $challengeToken);
    }
}
