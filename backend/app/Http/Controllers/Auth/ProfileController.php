<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ConfirmEmailChangeRequest;
use App\Http\Requests\Auth\ConfirmPhoneChangeRequest;
use App\Http\Requests\Auth\RequestEmailChangeRequest;
use App\Http\Requests\Auth\RequestPhoneChangeRequest;
use App\Http\Requests\Auth\UpdateFullNameRequest;
use App\Http\Requests\Auth\UpdateLanguagePreferenceRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\Auth\EmailOtpService;
use App\Services\Auth\OtpCooldownException;
use App\Services\Auth\OtpService;
use App\Services\Auth\PhoneNumberNormalizer;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

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

    public function updateName(UpdateFullNameRequest $request): UserResource
    {
        $user = $request->user();
        $user->update($request->only('full_name'));

        return new UserResource($user);
    }

    public function requestEmailChange(RequestEmailChangeRequest $request): JsonResponse
    {
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

    private function messageFor(?string $reason): string
    {
        return match ($reason) {
            'invalid_code' => 'That code is incorrect.',
            'too_many_attempts' => 'Too many incorrect attempts. Request a new code.',
            default => 'That code has expired or was never requested. Request a new one.',
        };
    }
}
