<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\CustomerLoginRequest;
use App\Http\Requests\Auth\RegisterCustomerRequest;
use App\Http\Requests\Auth\VerifyCustomerRegistrationRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\Auth\EmailOtpService;
use App\Services\Auth\OtpCooldownException;
use App\Services\Auth\PhoneNumberNormalizer;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Customer signup and login (product decision, Phase 11): email + password,
 * verified once via an emailed code — replacing the phone+SMS-OTP flow
 * Customer originally shared with Transporter Company. Transporter Company
 * is untouched; see AuthController.
 *
 * "Email OTP for now, SMS later" — the emailed code is a stand-in for the
 * same reason OtpService's phone flow exists: no real SMS provider is
 * connected yet (MAIL_MAILER=log here, same graceful-degradation posture
 * as SMS_DRIVER=log). Once real SMS is wired up, this could move to
 * phone-based verification without changing what happens afterward
 * (email+password remains how a Customer logs back in either way).
 *
 * The registration payload (including the already-hashed password — never
 * the plaintext) lives in the cache only, keyed by email, until the OTP is
 * verified — mirroring how phone+OTP never creates a User row until
 * verifyOtp() succeeds (AuthController). This means an abandoned signup
 * leaves no orphaned, unverified account behind.
 */
class CustomerAuthController extends Controller
{
    private const PENDING_REGISTRATION_PREFIX = 'customer_registration:';

    public function __construct(
        private readonly EmailOtpService $otp,
        private readonly DocumentStorage $documents,
    ) {}

    public function register(RegisterCustomerRequest $request): JsonResponse
    {
        $phone = $this->normalizedPhoneOrFail($request->string('phone_number'));

        // phone_number is unique across all account types (it's the login
        // identity for Transporter Company). The FormRequest can't check
        // this itself — normalization only happens here, after validation
        // — so an unnormalized "unique" rule could pass while the
        // normalized form still collides, hitting the DB constraint as an
        // uncaught 500 at User::create() instead of a clean 422.
        if (User::where('phone_number', $phone)->exists()) {
            throw ValidationException::withMessages([
                'phone_number' => ['This phone number is already registered.'],
            ]);
        }

        $logoKey = $request->hasFile('logo')
            ? $this->documents->store($request->file('logo'), 'customers/logos')
            : null;

        $pending = [
            'full_name' => $request->string('full_name')->toString(),
            'email' => $request->string('email')->toString(),
            'phone_number' => $phone,
            // Hashed immediately — a plaintext password is never written
            // to the cache, even briefly. The 'hashed' cast on
            // User::password_hash recognizes an already-hashed value and
            // won't re-hash it when the User row is finally created.
            'password_hash' => Hash::make($request->string('password')->toString()),
            'company_name' => $request->string('company_name')->toString() ?: null,
            'company_logo_url' => $logoKey,
        ];

        $ttl = now()->addSeconds(config('otp.ttl_seconds'));
        Cache::put($this->pendingKey($pending['email']), $pending, $ttl);

        try {
            $this->otp->issue($pending['email']);
        } catch (OtpCooldownException $e) {
            return response()->json([
                'message' => $e->getMessage(),
                'seconds_remaining' => $e->secondsRemaining,
            ], 429);
        }

        return response()->json(['message' => 'A verification code has been sent to your email.']);
    }

    public function verifyRegistration(VerifyCustomerRegistrationRequest $request): JsonResponse
    {
        $email = $request->string('email')->toString();

        $result = $this->otp->verify($email, $request->string('code'));

        if (! $result->successful) {
            throw ValidationException::withMessages(['code' => [$this->messageFor($result->reason)]]);
        }

        $pending = Cache::get($this->pendingKey($email));

        if (! is_array($pending)) {
            throw ValidationException::withMessages([
                'email' => ['Your registration session has expired. Please sign up again.'],
            ]);
        }

        Cache::forget($this->pendingKey($email));

        $user = User::create([
            'account_type' => 'customer',
            'full_name' => $pending['full_name'],
            'email' => $pending['email'],
            'phone_number' => $pending['phone_number'],
            'company_name' => $pending['company_name'],
            'company_logo_url' => $pending['company_logo_url'],
            'email_verified_at' => now(),
        ]);
        // password_hash is deliberately excluded from #[Fillable] (see
        // User's docblock) — set directly, same as CreateAdminUser.
        $user->password_hash = $pending['password_hash'];
        $user->save();

        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => new UserResource($user),
        ], 201);
    }

    public function login(CustomerLoginRequest $request): JsonResponse
    {
        $user = User::where('account_type', 'customer')
            ->where('email', $request->string('email'))
            ->first();

        if (! $user || ! Hash::check($request->string('password'), $user->password_hash ?? '')) {
            // Same message either way — don't reveal whether the email
            // belongs to an account (same reasoning as AdminAuthController).
            throw ValidationException::withMessages(['email' => ['Invalid credentials.']]);
        }

        return response()->json([
            'token' => $user->createToken('mobile-app')->plainTextToken,
            'user' => new UserResource($user),
        ]);
    }

    private function normalizedPhoneOrFail(string $rawPhone): string
    {
        try {
            return PhoneNumberNormalizer::normalize($rawPhone);
        } catch (\InvalidArgumentException $e) {
            throw ValidationException::withMessages(['phone_number' => [$e->getMessage()]]);
        }
    }

    private function pendingKey(string $email): string
    {
        return self::PENDING_REGISTRATION_PREFIX.$email;
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
