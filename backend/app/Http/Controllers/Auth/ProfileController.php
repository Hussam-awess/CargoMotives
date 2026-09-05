<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\CompleteProfileRequest;
use App\Http\Resources\UserResource;
use Illuminate\Validation\ValidationException;

/**
 * Customer profile completion only (AppFlow §1: "Customer -> name, optional
 * company name -> Customer Home"). A Transporter Company's equivalent step
 * is the two-section verification flow against transporter_companies
 * (Phase 2) — a different shape entirely (business info + a verified
 * representative, not a simple name field) — so it's intentionally not
 * handled here rather than half-supported.
 *
 * Doc note: the PRD/AppFlow mention an optional "company name" field on the
 * Customer's profile, but the Backend Schema's users table (§2.1) has no
 * such column. Followed the schema (the more detailed, authoritative source
 * for persistence) rather than inventing an undocumented column — flagging
 * this discrepancy here for whoever reconciles the docs later.
 */
class ProfileController extends Controller
{
    public function complete(CompleteProfileRequest $request): UserResource
    {
        $user = $request->user();

        if ($user->account_type !== 'customer') {
            throw ValidationException::withMessages([
                'account_type' => ['Transporter companies complete verification instead of a simple profile — see the company verification flow.'],
            ]);
        }

        $user->update($request->only('full_name', 'language_preference'));

        return new UserResource($user);
    }
}
