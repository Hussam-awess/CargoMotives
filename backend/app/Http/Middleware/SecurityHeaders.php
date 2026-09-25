<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Baseline browser-security headers on every response. Mostly matters for
 * the server-rendered pages (legal, Driver Link, Admin) — the JSON API is
 * consumed by the mobile app, not a browser — but applying them globally
 * costs nothing and means a future page can't forget them.
 *
 * HSTS is only sent over HTTPS (it's ignored on plain HTTP anyway, and
 * sending it from local dev would be pointless noise).
 */
class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $headers = $response->headers;
        $headers->set('X-Content-Type-Options', 'nosniff');
        $headers->set('X-Frame-Options', 'DENY');
        $headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        // No page served here uses a powerful browser feature (truck
        // location comes from the GPS provider, not the driver's browser).
        $headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');

        if ($request->isSecure()) {
            $headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
        }

        return $response;
    }
}
