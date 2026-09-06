<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Gates a route behind the authenticated Transporter Company's own
 * verification_status being 'approved' (PRD §6: registering trucks, and
 * later bidding, both come strictly after Admin approval). Runs after
 * `auth:sanctum` and `account_type:transporter_company`, so
 * $request->user() is always a transporter_company account by the time
 * this checks it.
 *
 * A second reusable gate alongside EnsureAccountType — Phase 4 needs this
 * exact same check again for bidding (Backend Schema §4.2).
 */
class EnsureCompanyApproved
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()->transporterCompany?->verification_status !== 'approved') {
            abort(403, 'Your company must be verified before you can do this.');
        }

        return $next($request);
    }
}
