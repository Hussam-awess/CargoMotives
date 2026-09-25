<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\UpdateCompanyPreferencesRequest;
use App\Http\Resources\CompanyResource;

/**
 * Small standalone company preferences that don't belong in the
 * verification flow (CompanyVerificationController) — same "not part of
 * verification, nothing to re-verify" reasoning as that controller's own
 * updateLocation(). Two independent preferences live here:
 *
 * - `auto_decline_below_budget` + `floor_rate`: actually filters the Open
 *   Jobs feed now (CompanyJobController::applyFloorRateFilter()) — this
 *   used to be a mobile-only toggle that wrote nowhere.
 * - `display_currency`: purely cosmetic, formats the company's own Plus
 *   subscription price on featured_screen.dart. Never affects a job's or
 *   bid's own currency, which always stays whatever the posting customer
 *   chose (this app has no currency-conversion system).
 */
class CompanyPreferencesController extends Controller
{
    public function update(UpdateCompanyPreferencesRequest $request): CompanyResource
    {
        $company = $request->user()->transporterCompany;
        abort_if($company === null, 404);

        $attributes = $request->validated();

        // One currency concept per company, not two independently-managed
        // ones — a floor rate is always denominated in whatever the
        // company's own display currency currently is (either just set in
        // this same request, or the value already on file).
        if (array_key_exists('floor_rate', $attributes)) {
            $attributes['floor_rate_currency'] = $attributes['display_currency'] ?? $company->display_currency;
        }

        $company->update($attributes);

        return new CompanyResource($company);
    }
}
