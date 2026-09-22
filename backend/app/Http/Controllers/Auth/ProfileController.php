<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Http\Requests\Auth\ConfirmEmailChangeRequest;
use App\Http\Requests\Auth\ConfirmPhoneChangeRequest;
use App\Http\Requests\Auth\RequestEmailChangeRequest;
use App\Http\Requests\Auth\RequestPhoneChangeRequest;
use App\Http\Requests\Auth\UpdateAvatarRequest;
use App\Http\Requests\Auth\UpdateBusinessIdentityRequest;
use App\Http\Requests\Auth\UpdateEmailRequest;
use App\Http\Requests\Auth\UpdateFullNameRequest;
use App\Http\Requests\Auth\UpdateLanguagePreferenceRequest;
use App\Http\Requests\Auth\UpdateNotificationPreferencesRequest;
use App\Http\Requests\Auth\UpdatePhoneRequest;
use App\Http\Requests\Auth\UpdatePreferredCurrencyRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\Auth\EmailOtpService;
use App\Services\Auth\OtpCooldownException;
use App\Services\Auth\OtpService;
use App\Services\Auth\PhoneNumberNormalizer;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Cross-role account-preference updates. Customer profile completion
 * (full_name etc.) no longer lives here — Phase 11 moved Customer to
 * email+password registration, which collects full_name up front, so
 * there's no longer a separate "complete your profile" step for it.
 * Transporter Company's equivalent is still the two-section verification
 * flow against transporter_companies (Phase 2) — a different shape
 * entirely (business info + a verified representative).
 *
 * Phase 10.16 adds real profile editing: full_name updates immediately
 * (it's not a login credential), but email (Customer's login credential)
 * and phone_number (Transporter Company's) require confirming a code sent
 * to the *new* value first — reusing EmailOtpService/OtpService exactly as
 * registration already does, just keyed by the new value instead of a
 * pending-registration one. No new cache shape needed: issue()/verify()
 * are already generic over "what string is this code for."
 */
class ProfileController extends Controller
{
    public function __construct(
        private readonly EmailOtpService $emailOtp,
        private readonly OtpService $otp,
        private readonly DocumentStorage $documents,
    ) {}

    /**
     * Changeable any time after signup, from either role's Profile screen
     * — not tied to any one-time onboarding step.
     */
    public function updateLanguage(UpdateLanguagePreferenceRequest $request): UserResource
    {
        $user = $request->user();
        $user->update($request->only('language_preference'));

        return new UserResource($user);
    }

    /**
     * A denomination choice for a customer's own future job postings — not
     * a currency-conversion setting, see UpdatePreferredCurrencyRequest's
     * migration docblock. Changeable any time, same as language.
     */
    public function updatePreferredCurrency(UpdatePreferredCurrencyRequest $request): UserResource
    {
        $user = $request->user();
        $user->update($request->only('preferred_currency'));

        return new UserResource($user);
    }

    public function updateName(UpdateFullNameRequest $request): UserResource
    {
        $user = $request->user();
        $user->update($request->only('full_name'));

        return new UserResource($user);
    }

    /**
     * Merges into the existing map (see the request's own docblock) rather
     * than replacing it, so toggling one Settings switch never silently
     * resets whatever the user chose for the others.
     */
    public function updateNotificationPreferences(UpdateNotificationPreferencesRequest $request): UserResource
    {
        $user = $request->user();
        $merged = array_merge($user->notification_preferences ?? [], $request->validated());
        $user->update(['notification_preferences' => $merged]);

        return new UserResource($user);
    }

    /**
     * A personal profile photo, distinct from a Customer's optional
     * business logo (updateBusinessIdentity) and a TransporterCompany's own
     * logo — available to every account_type, applies immediately (not a
     * credential).
     */
    public function updateAvatar(UpdateAvatarRequest $request): UserResource
    {
        $user = $request->user();
        $key = $this->documents->store($request->file('avatar'), 'users/avatars');
        $user->update(['avatar_url' => $key]);

        return new UserResource($user);
    }

    /**
     * Immediate, unverified update — for whichever of phone/email is NOT
     * the caller's login credential (see ensureNotCredentialField). The
     * credential itself still goes through request/confirm-change above.
     */
    public function updatePhone(UpdatePhoneRequest $request): UserResource
    {
        $user = $request->user();
        $this->ensureNotCredentialField($user, 'phone_number');

        try {
            $normalized = PhoneNumberNormalizer::normalize($request->string('phone_number')->toString());
        } catch (\InvalidArgumentException $e) {
            throw ValidationException::withMessages(['phone_number' => [$e->getMessage()]]);
        }

        if (User::where('phone_number', $normalized)->where('id', '!=', $user->id)->exists()) {
            throw ValidationException::withMessages(['phone_number' => ['That phone number is already in use.']]);
        }

        $user->update(['phone_number' => $normalized]);

        return new UserResource($user);
    }

    public function updateEmail(UpdateEmailRequest $request): UserResource
    {
        $user = $request->user();
        $this->ensureNotCredentialField($user, 'email');

        $email = $request->string('email')->toString();

        if (User::where('email', $email)->where('id', '!=', $user->id)->exists()) {
            throw ValidationException::withMessages(['email' => ['That email is already in use.']]);
        }

        $user->update(['email' => $email]);

        return new UserResource($user);
    }

    /**
     * Real, authenticated "change password" — distinct from the
     * forgot-password flow (AuthController/CustomerAuthController), which
     * exists precisely for when the caller does NOT know the current
     * password. Here they must prove they do. Every *other* session is
     * revoked (same reasoning as a password reset), but the one making
     * this request is deliberately left alone — they just proved they're
     * the account owner, so there's no reason to also log them out.
     */
    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        $user = $request->user();
        $this->verifyCurrentPassword($user, $request->string('current_password')->toString());

        $user->password_hash = Hash::make($request->string('password')->toString());
        $user->save();

        // currentAccessToken() is Sanctum's real PersonalAccessToken for an
        // actual bearer-token request; ->id is guarded since it comes back
        // as a plain TransientToken (no ->id) under actingAs() in tests.
        $currentToken = $request->user()->currentAccessToken();
        $currentTokenId = $currentToken instanceof PersonalAccessToken ? $currentToken->id : null;
        $user->tokens()->when($currentTokenId, fn ($query) => $query->where('id', '!=', $currentTokenId))->delete();

        return response()->json(['message' => 'Password changed.']);
    }

    /**
     * A Customer's optional business identity (company_name + logo) — the
     * same fields RegisterCustomerRequest collects at signup, now editable
     * afterward. Rejects every other account_type: a TransporterCompany's
     * business identity is a heavier, Admin-reviewed resubmission
     * (CompanyVerificationScreen), not a plain settings edit.
     */
    public function updateBusinessIdentity(UpdateBusinessIdentityRequest $request): UserResource
    {
        $user = $request->user();

        if ($user->account_type !== 'customer') {
            throw ValidationException::withMessages([
                'company_name' => ['Only Customer accounts have an editable business identity.'],
            ]);
        }

        $attributes = ['company_name' => $request->string('company_name')->toString() ?: null];

        if ($request->hasFile('logo')) {
            $attributes['company_logo_url'] = $this->documents->store($request->file('logo'), 'customers/logos');
        }

        $user->update($attributes);

        return new UserResource($user);
    }

    public function requestEmailChange(RequestEmailChangeRequest $request): JsonResponse
    {
        $this->verifyCurrentPassword($request->user(), $request->string('current_password')->toString());

        try {
            $this->emailOtp->issue($request->validated('new_email'));
        } catch (OtpCooldownException $e) {
            return response()->json(['message' => $e->getMessage(), 'seconds_remaining' => $e->secondsRemaining], 429);
        }

        return response()->json(['message' => 'A confirmation code was sent to the new email address.']);
    }

    public function confirmEmailChange(ConfirmEmailChangeRequest $request): UserResource
    {
        $newEmail = $request->validated('new_email');

        // Re-checked here, not just at request-change time: another
        // account could have claimed this email in the gap between the two
        // steps.
        if (User::where('email', $newEmail)->where('id', '!=', $request->user()->id)->exists()) {
            throw ValidationException::withMessages(['new_email' => ['That email is already in use.']]);
        }

        $result = $this->emailOtp->verify($newEmail, $request->validated('code'));

        if (! $result->successful) {
            throw ValidationException::withMessages(['code' => [$this->messageFor($result->reason)]]);
        }

        $user = $request->user();
        $user->update(['email' => $newEmail]);

        return new UserResource($user);
    }

    public function requestPhoneChange(RequestPhoneChangeRequest $request): JsonResponse
    {
        $this->verifyCurrentPassword($request->user(), $request->string('current_password')->toString());

        try {
            $normalized = PhoneNumberNormalizer::normalize($request->validated('new_phone'));
        } catch (\InvalidArgumentException $e) {
            throw ValidationException::withMessages(['new_phone' => [$e->getMessage()]]);
        }

        if (User::where('phone_number', $normalized)->where('id', '!=', $request->user()->id)->exists()) {
            throw ValidationException::withMessages(['new_phone' => ['That phone number is already in use.']]);
        }

        try {
            $this->otp->issue($normalized);
        } catch (OtpCooldownException $e) {
            return response()->json(['message' => $e->getMessage(), 'seconds_remaining' => $e->secondsRemaining], 429);
        }

        return response()->json(['message' => 'A confirmation code was sent to the new phone number.']);
    }

    public function confirmPhoneChange(ConfirmPhoneChangeRequest $request): UserResource
    {
        try {
            $normalized = PhoneNumberNormalizer::normalize($request->validated('new_phone'));
        } catch (\InvalidArgumentException $e) {
            throw ValidationException::withMessages(['new_phone' => [$e->getMessage()]]);
        }

        if (User::where('phone_number', $normalized)->where('id', '!=', $request->user()->id)->exists()) {
            throw ValidationException::withMessages(['new_phone' => ['That phone number is already in use.']]);
        }

        $result = $this->otp->verify($normalized, $request->validated('code'));

        if (! $result->successful) {
            throw ValidationException::withMessages(['code' => [$this->messageFor($result->reason)]]);
        }

        $user = $request->user();
        $user->update(['phone_number' => $normalized]);

        return new UserResource($user);
    }

    /**
     * phone_number is the Transporter Company's login credential;
     * email is the Customer's — either must go through the
     * request/confirm-change flow above, never this endpoint's plain
     * update, or a signed-in session could silently hijack its own login
     * credential without proving it still controls the new value.
     */
    private function ensureNotCredentialField(User $user, string $field): void
    {
        $isCredential = match ($user->account_type) {
            'customer' => $field === 'email',
            'transporter_company' => $field === 'phone_number',
            default => false,
        };

        if ($isCredential) {
            throw ValidationException::withMessages([
                $field => ['This is your login credential — use the confirm-change flow instead.'],
            ]);
        }
    }

    /**
     * Gate for every high-risk profile action that changes a login
     * credential (email/phone request-change, password change): a signed-in
     * session alone isn't enough proof for these, since a session can be
     * hijacked (a shared/unlocked device, a leaked token) without the
     * attacker ever learning the password.
     */
    private function verifyCurrentPassword(User $user, string $currentPassword): void
    {
        if (! Hash::check($currentPassword, $user->password_hash ?? '')) {
            throw ValidationException::withMessages(['current_password' => ['That password is incorrect.']]);
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
