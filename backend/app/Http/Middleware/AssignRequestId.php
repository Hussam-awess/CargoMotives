<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * Tags every request with an id that ends up on every log line it writes
 * and on the response's X-Request-Id header. The mobile app sends its own
 * id and shows it in error messages, so a user's "it said error ref
 * 3f9c…" can be matched straight to the server log for that exact
 * request.
 *
 * A client-supplied id is only accepted if it looks like one (short,
 * [A-Za-z0-9-]) so it can't be used to inject arbitrary text into logs.
 */
class AssignRequestId
{
    public function handle(Request $request, Closure $next): Response
    {
        $incoming = (string) $request->headers->get('X-Request-Id', '');
        $requestId = preg_match('/^[A-Za-z0-9-]{8,64}$/', $incoming) === 1 ? $incoming : (string) Str::uuid();

        $request->headers->set('X-Request-Id', $requestId);
        Log::withContext(['request_id' => $requestId]);

        $response = $next($request);
        $response->headers->set('X-Request-Id', $requestId);

        return $response;
    }
}
