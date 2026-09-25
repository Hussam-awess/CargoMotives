<?php

namespace App\Http\Controllers\Profiles;

use App\Http\Controllers\Controller;
use App\Http\Resources\CompanyProfileResource;
use App\Http\Resources\PublicReviewResource;
use App\Models\JobReview;
use App\Models\TransporterCompany;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * A transporter company's public profile (Phase: public profiles) —
 * reachable by any authenticated user. See CompanyProfileResource's
 * docblock for exactly what's shown vs. kept private.
 */
class CompanyProfileController extends Controller
{
    public function show(Request $request, TransporterCompany $company): CompanyProfileResource
    {
        // The owner soft-deleted their account (AccountDeletionService) —
        // the company row survives for job history, but is no longer a
        // public profile anyone can browse.
        abort_if($company->owner === null, 404, 'This company is no longer on Cargo Motives.');

        return new CompanyProfileResource($company);
    }

    public function reviews(Request $request, TransporterCompany $company): AnonymousResourceCollection
    {
        return PublicReviewResource::collection(
            JobReview::where('ratee_company_id', $company->id)->latest('created_at')->paginate(20)
        );
    }
}
