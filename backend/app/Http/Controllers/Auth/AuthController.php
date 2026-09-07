<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\RequestOtpRequest;
use App\Http\Requests\Auth\VerifyOtpRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\Auth\OtpCooldownException;
use App\Services\Auth\OtpService;
use App\Services\Auth\PhoneNumberNormalizer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Phone/OTP authentication for Transporter Company (PRD §6, AppFlow §1
 * originally; Customer moved to email+password in Phase 11 — see
 * CustomerAuthController). Admin uses a separate web login (Phase 9), and
 * Drivers never authenticate at all (Driver Link tokens, Phase 5).
 */
class AuthController extends Controller
{
    public function __construct(private readonly OtpService $otp) {}

    public function requestOtp(RequestOtpRequest $request): JsonResponse
    {
        $phone = $this->normalizedPhoneOrFail($request->string('phone_number'));

        $this->assertAccountTypeConsistent($phone, $request->string('account_type'));

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
        $email = $request->string('email')->toString();

        $this->assertAccountTypeConsistent($phone, $accountType);

        $result = $this->otp->verify($phone, $request->string('code'));

        if (! $result->successful) {
            throw ValidationException::withMessages(['code' => [$this->messageFor($result->reason)]]);
        }

        $existing = User::where('phone_number', $phone)->first();

        if ($existing === null && User::where('email', $email)->exists()) {
            // Only a problem for a genuinely new account — an existing
            // user re-verifying (e.g. re-requested a code) keeps whatever
            // email it already has, firstOrCreate below won't touch it.
            throw ValidationException::withMessages([
                'email' => ['This email is already registered.'],
            ]);
        }

        $user = User::firstOrCreate(
            ['phone_number' => $phone],
            ['account_type' => $accountType, 'full_name' => $request->string('full_name'), 'email' => $email],
        );

        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => new UserResource($user),
        ]);
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

    private function messageFor(?string $reason): string
    {
        return match ($reason) {
            'invalid_code' => 'That code is incorrect.',
            'too_many_attempts' => 'Too many incorrect attempts. Request a new code.',
            default => 'That code has expired or was never requested. Request a new one.',
        };
    }
}
