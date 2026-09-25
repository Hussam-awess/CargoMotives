<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Concerns\HandlesLoginLockout;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\CompanyLoginRequest;
use App\Http\Requests\Auth\ConfirmPasswordResetRequest;
use App\Http\Requests\Auth\RequestOtpRequest;
use App\Http\Requests\Auth\RequestPasswordResetRequest;
use App\Http\Requests\Auth\VerifyOtpRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\Auth\DeviceName;
use App\Services\Auth\LoginThrottle;
use App\Services\Auth\OtpCooldownException;
use App\Services\Auth\OtpService;
use App\Services\Auth\PhoneNumberNormalizer;
use App\Services\Auth\TwoFactorChallenge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Phone/OTP authentication for Transporter Company (PRD §6, AppFlow §1
 * originally; Customer moved to email+password in Phase 11 — see
 * CustomerAuthController). Admin uses a separate web login (Phase 9), and
 * Drivers never authenticate at all (Driver Link tokens, Phase 5).
 *
 * Design-import restyle: full_name/email/password are now collected at
 * request-time (matching the mockup's "Step 1 — Account" screen) rather
 * than at verify-time, and a password-based login() exists alongside the
 * OTP flow — mirroring CustomerAuthController's pending-cache pattern
 * exactly (hash immediately, stash pending, never a plaintext password
 * anywhere, create the User only once the code verifies).
 */
class AuthController extends Controller
{
    use HandlesLoginLockout;

    private const PENDING_REGISTRATION_PREFIX = 'transporter_registration:';

    public function __construct(
        private readonly OtpService $otp,
        private readonly LoginThrottle $loginThrottle,
        private readonly TwoFactorChallenge $twoFactor,
    ) {}

    public function requestOtp(RequestOtpRequest $request): JsonResponse
    {
        $phone = $this->normalizedPhoneOrFail($request->string('phone_number'));

        $this->assertAccountTypeConsistent($phone, $request->string('account_type'));

        $pending = [
            'full_name' => $request->string('full_name')->toString(),
            'email' => $request->string('email')->toString(),
            'phone_number' => $phone,
            // Hashed immediately, same as CustomerAuthController::register()
            // — never written to the cache in plaintext, even briefly.
            'password_hash' => Hash::make($request->string('password')->toString()),
        ];

        Cache::put($this->pendingKey($phone), $pending, now()->addSeconds(config('otp.ttl_seconds')));

        try {
            $this->otp->issue($phone);
        } catch (OtpCooldownException $e) {
            return response()->json([
                'message' => $e->getMessage(),
                'seconds_remaining' => $e->secondsRemaining,
            ], 429);
        }

        // Deliberately generic — never confirms or denies whether this
        // phone number already has an account, to avoid letting the
        // endpoint be used to enumerate registered users.
        return response()->json(['message' => 'If the number is valid, a verification code has been sent.']);
    }

    public function verifyOtp(VerifyOtpRequest $request): JsonResponse
    {
        $phone = $this->normalizedPhoneOrFail($request->string('phone_number'));
        $accountType = $request->string('account_type')->toString();

        $this->assertAccountTypeConsistent($phone, $accountType);

        $result = $this->otp->verify($phone, $request->string('code'));

        if (! $result->successful) {
            throw ValidationException::withMessages(['code' => [$this->messageFor($result->reason)]]);
        }

        $existing = User::where('phone_number', $phone)->first();

        if ($existing !== null) {
            Cache::forget($this->pendingKey($phone));

            // With two-factor on, a phone code alone must not be enough to
            // get in — that's exactly the one-factor path 2FA exists to
            // close (e.g. a SIM-swapped number). Password + code only.
            if ($existing->two_factor_enabled) {
                throw ValidationException::withMessages([
                    'phone_number' => ['This number already has an account. Log in with your password instead.'],
                ]);
            }

            // Already has an account (e.g. re-requested a code) — nothing
            // left to create, just issue a fresh token.
            $token = $existing->createToken(DeviceName::from($request))->plainTextToken;

            return response()->json(['token' => $token, 'user' => new UserResource($existing)]);
        }

        $pending = Cache::get($this->pendingKey($phone));

        if (! is_array($pending)) {
            throw ValidationException::withMessages([
                'phone_number' => ['Your registration session has expired. Please sign up again.'],
            ]);
        }

        if (User::where('email', $pending['email'])->exists()) {
            throw ValidationException::withMessages([
                'email' => ['This email is already registered.'],
            ]);
        }

        Cache::forget($this->pendingKey($phone));

        $user = User::create([
            'account_type' => $accountType,
            'full_name' => $pending['full_name'],
            'email' => $pending['email'],
            'phone_number' => $pending['phone_number'],
        ]);
        // password_hash is deliberately excluded from #[Fillable] (see
        // User's docblock) — set directly, same as CustomerAuthController.
        $user->password_hash = $pending['password_hash'];
        $user->save();

        $token = $user->createToken(DeviceName::from($request))->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => new UserResource($user),
        ], 201);
    }

    /**
     * Password-based login for a Transporter Company that already
     * completed phone+OTP signup — mirrors CustomerAuthController::login()
     * exactly. OTP itself is a one-time signup-verification step, never
     * asked again here.
     */
    public function login(CompanyLoginRequest $request): JsonResponse
    {
        $phone = $this->normalizedPhoneOrFail($request->string('phone_number'));
        $throttleKey = "company:{$phone}";

        if ($this->loginThrottle->locked($throttleKey)) {
            return $this->lockoutResponse($throttleKey);
        }

        $user = User::where('account_type', 'transporter_company')
            ->where('phone_number', $phone)
            ->first();

        if (! $user || ! Hash::check($request->string('password'), $user->password_hash ?? '')) {
            $this->loginThrottle->recordFailure($throttleKey);

            // Same message either way — don't reveal whether the number
            // belongs to an account (same reasoning as CustomerAuthController).
            throw ValidationException::withMessages(['phone_number' => ['Invalid credentials.']]);
        }

        $this->loginThrottle->clear($throttleKey);

        if ($user->two_factor_enabled) {
            return response()->json($this->twoFactor->start($user, DeviceName::from($request)));
        }

        return response()->json([
            'token' => $user->createToken(DeviceName::from($request))->plainTextToken,
            'user' => new UserResource($user),
        ]);
    }

    /**
     * Forgot password (mirrors requestOtp()'s generic-response reasoning):
     * reuses OtpService's existing issue()/verify() pair keyed by the
     * account's own phone number rather than a pending-registration one —
     * same reuse ProfileController::requestPhoneChange() already does.
     */
    public function requestPasswordReset(RequestPasswordResetRequest $request): JsonResponse
    {
        $phone = $this->normalizedPhoneOrFail($request->string('phone_number'));

        $user = User::where('account_type', 'transporter_company')->where('phone_number', $phone)->first();

        if ($user !== null) {
            try {
                $this->otp->issue($phone);
            } catch (OtpCooldownException $e) {
                return response()->json([
                    'message' => $e->getMessage(),
                    'seconds_remaining' => $e->secondsRemaining,
                ], 429);
            }
        }

        // Deliberately generic — never confirms or denies whether this
        // phone number has an account, same reasoning as requestOtp().
        return response()->json(['message' => 'If that number has an account, a reset code has been sent.']);
    }

    public function confirmPasswordReset(ConfirmPasswordResetRequest $request): JsonResponse
    {
        $phone = $this->normalizedPhoneOrFail($request->string('phone_number'));

        $result = $this->otp->verify($phone, $request->string('code'));

        if (! $result->successful) {
            throw ValidationException::withMessages(['code' => [$this->messageFor($result->reason)]]);
        }

        $user = User::where('account_type', 'transporter_company')->where('phone_number', $phone)->first();

        if ($user === null) {
            throw ValidationException::withMessages(['phone_number' => ['No account found for that number.']]);
        }

        $user->password_hash = Hash::make($request->string('password')->toString());
        $user->save();

        // Every existing session is revoked — a device that was already
        // logged in (possibly by whoever needed the reset in the first
        // place) shouldn't stay signed in past a password reset.
        $user->tokens()->delete();

        return response()->json(['message' => 'Password reset. You can now log in with your new password.']);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    public function me(Request $request): UserResource
    {
        return new UserResource($request->user());
    }

    private function normalizedPhoneOrFail(string $rawPhone): string
    {
        try {
            return PhoneNumberNormalizer::normalize($rawPhone);
        } catch (\InvalidArgumentException $e) {
            throw ValidationException::withMessages(['phone_number' => [$e->getMessage()]]);
        }
    }

    /**
     * A phone number belongs to exactly one account_type for its lifetime.
     * Without this check, a customer's number could silently be reused to
     * spin up a transporter_company account (or vice versa) the moment
     * they pick the "wrong" role on the Welcome screen.
     */
    private function assertAccountTypeConsistent(string $phone, string $requestedAccountType): void
    {
        $existing = User::where('phone_number', $phone)->first();

        if ($existing && $existing->account_type !== $requestedAccountType) {
            throw ValidationException::withMessages([
                'account_type' => ["This number is already registered as a {$existing->account_type}. Choose that role instead."],
            ]);
        }
    }

    private function pendingKey(string $phone): string
    {
        return self::PENDING_REGISTRATION_PREFIX.$phone;
    }

    private function messageFor(?string $reason): string
    {
        return match ($reason) {
            'invalid_code' => 'That code is incorrect.',
            'too_many_attempts' => 'Too many incorrect attempts. Request a new code.',
            default => 'That code has expired or was never requested. Request a new one.',
        };
    }
}
