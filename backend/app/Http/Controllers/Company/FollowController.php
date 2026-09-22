<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Resources\FollowedCustomerResource;
use App\Models\CustomerFollow;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * A transporter company choosing which customers' new job postings it
 * wants to hear about — replaces the old "every approved company is
 * notified of every new job" broadcast. See JobObserver::created() for
 * the notification-gating side of this.
 */
class FollowController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $companyId = $request->user()->transporterCompany->id;

        $customerIds = CustomerFollow::where('transporter_company_id', $companyId)->pluck('customer_id');

        return FollowedCustomerResource::collection(User::whereIn('id', $customerIds)->get());
    }

    public function store(Request $request, User $customer): JsonResponse
    {
        abort_unless($customer->account_type === 'customer', 404);

        CustomerFollow::firstOrCreate([
            'transporter_company_id' => $request->user()->transporterCompany->id,
            'customer_id' => $customer->id,
        ]);

        return response()->json(['is_following' => true]);
    }

    public function destroy(Request $request, User $customer): JsonResponse
    {
        abort_unless($customer->account_type === 'customer', 404);

        CustomerFollow::where('transporter_company_id', $request->user()->transporterCompany->id)
            ->where('customer_id', $customer->id)
            ->delete();

        return response()->json(['is_following' => false]);
    }
}
