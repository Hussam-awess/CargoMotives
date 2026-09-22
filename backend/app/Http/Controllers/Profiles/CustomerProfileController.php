<?php

namespace App\Http\Controllers\Profiles;

use App\Http\Controllers\Controller;
use App\Http\Resources\CustomerProfileResource;
use App\Http\Resources\PublicReviewResource;
use App\Models\JobReview;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * A customer's public profile (Phase: public profiles) — reachable by any
 * authenticated user, not just a transporter who happens to share a job
 * with this customer (see CustomerProfileResource's docblock on why
 * "recent completed jobs" is always anonymized rather than
 * viewer-conditional).
 */
class CustomerProfileController extends Controller
{
    public function show(Request $request, User $customer): CustomerProfileResource
    {
        abort_unless($customer->account_type === 'customer', 404);

        return new CustomerProfileResource($customer);
    }

    public function reviews(Request $request, User $customer): AnonymousResourceCollection
    {
        abort_unless($customer->account_type === 'customer', 404);

        return PublicReviewResource::collection(
            JobReview::where('ratee_customer_id', $customer->id)->latest('created_at')->paginate(20)
        );
    }
}
