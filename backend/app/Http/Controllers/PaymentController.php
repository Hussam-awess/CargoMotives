<?php

namespace App\Http\Controllers;

use App\Http\Resources\PaymentResource;
use App\Models\Payment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Payment history — shared between Customer and Company (Backend Schema
 * §2.14), since `payments.user_id` scopes a payment to whichever role's own
 * User row initiated it, identically either way. Registered under both
 * `/payments` (customer) and `/company/payments` (company), same as
 * MessageController is shared across roles rather than duplicated.
 */
class PaymentController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return PaymentResource::collection(
            Payment::where('user_id', $request->user()->id)->latest()->paginate(20)
        );
    }
}
