<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\TruckResource;
use App\Models\Truck;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Minimal Admin truck-review tooling (PRD §10 item 2), same shape as
 * AdminCompanyController — the full Admin tool is Phase 9.
 */
class AdminTruckController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $query = Truck::query()->latest();

        if ($status = $request->string('status')->toString()) {
            $query->where('verification_status', $status);
        }

        return TruckResource::collection($query->paginate(20));
    }

    public function show(Truck $truck): TruckResource
    {
        return new TruckResource($truck);
    }

    public function approve(Truck $truck): TruckResource
    {
        $truck->update(['verification_status' => 'approved', 'verification_rejected_reason' => null]);

        return new TruckResource($truck);
    }

    public function reject(Request $request, Truck $truck): TruckResource
    {
        $request->validate(['reason' => ['required', 'string', 'max:1000']]);

        $truck->update([
            'verification_status' => 'rejected',
            'verification_rejected_reason' => $request->string('reason'),
        ]);

        return new TruckResource($truck);
    }
}
