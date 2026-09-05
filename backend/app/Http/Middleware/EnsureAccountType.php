<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Restricts a route to one or more account_type values, e.g.
 * `middleware('account_type:transporter_company')` or
 * `middleware('account_type:admin')`. Runs after `auth:sanctum`, so
 * $request->user() is always present by the time this checks it.
 *
 * A generic, reusable gate rather than one-off checks scattered across
 * controllers — every phase from here on adds more account-type-scoped
 * endpoints (company-only bidding, customer-only job posting, admin-only
 * review actions), and they should all fail the same way.
 */
class EnsureAccountType
{
    public function handle(Request $request, Closure $next, string ...$allowedTypes): Response
    {
        if (! in_array($request->user()?->account_type, $allowedTypes, true)) {
            abort(403, 'This action is not available for your account type.');
        }

        return $next($request);
    }
}
