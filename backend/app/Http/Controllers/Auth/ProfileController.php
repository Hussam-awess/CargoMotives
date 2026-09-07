<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\UpdateLanguagePreferenceRequest;
use App\Http\Resources\UserResource;

/**
 * Cross-role account-preference updates. Customer profile completion
 * (full_name etc.) no longer lives here — Phase 11 moved Customer to
 * email+password registration, which collects full_name up front, so
 * there's no longer a separate "complete your profile" step for it.
 * Transporter Company's equivalent is still the two-section verification
 * flow against transporter_companies (Phase 2) — a different shape
 * entirely (business info + a verified representative).
 */
class ProfileController extends Controller
{
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
}
