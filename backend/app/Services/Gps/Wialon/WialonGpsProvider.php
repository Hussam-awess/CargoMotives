<?php

namespace App\Services\Gps\Wialon;

use App\Services\Gps\GpsProvider;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsUnit;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Wialon Hosting API (https://hst-api.wialon.com) integration — the one
 * GPS provider this MVP proves the whole pattern with (Phase 6; Traccar
 * and Tracksolid Pro follow later as their own concrete classes, not a
 * generalized abstraction built ahead of them).
 *
 * Wialon's API is a single RPC-style endpoint (`/wialon/ajax.html`) where
 * every call passes `svc` (the operation name) and `params` (a JSON blob),
 * authenticated calls also passing the session id (`sid`) returned by
 * logging in with a company's API token. Sessions are short-lived, so each
 * [listUnits] call here logs in fresh, queries, and logs out — simpler and
 * more robust for a periodic poll job than juggling session expiry across
 * calls, at the cost of one extra round trip per poll (acceptable at this
 * app's scale per TRD §10's "right-sized, not over-built" guidance).
 */
class WialonGpsProvider implements GpsProvider
{
    public function __construct(private readonly string $baseUrl) {}

    public function listUnits(string $accessToken): array
    {
        $sessionId = $this->login($accessToken);

        try {
            return $this->searchUnits($sessionId);
        } finally {
            // Best-effort cleanup — a failed logout must never mask (or
            // replace) whatever listUnits() itself returned/threw.
            try {
                $this->call('core/logout', ['sid' => $sessionId]);
            } catch (Throwable) {
                // Ignored deliberately.
            }
        }
    }

    private function login(string $accessToken): string
    {
        $response = $this->call('token/login', ['token' => $accessToken]);

        if (! isset($response['eid'])) {
            throw new GpsProviderException('Wialon rejected this API token. Check it and try again.');
        }

        return $response['eid'];
    }

    /**
     * @return array<int, GpsUnit>
     */
    private function searchUnits(string $sessionId): array
    {
        $response = $this->call('core/search_items', [
            'spec' => [
                'itemsType' => 'avl_unit',
                'propName' => 'sys_name',
                'propValueMask' => '*',
                'sortType' => 'sys_name',
            ],
            'force' => 1,
            // flags=1025 = base item info (1) + last known position (1024)
            // in one call — Wialon's real API returns position alongside
            // the unit list, no separate "get position" endpoint needed.
            'flags' => 1025,
            'from' => 0,
            'to' => 0,
        ], $sessionId);

        return collect($response['items'] ?? [])->map(function (array $item) {
            $pos = $item['pos'] ?? null;

            return new GpsUnit(
                unitId: (string) $item['id'],
                name: (string) ($item['nm'] ?? $item['id']),
                lat: $pos['y'] ?? null,
                lng: $pos['x'] ?? null,
                heading: $pos['c'] ?? null,
                recordedAt: isset($pos['t']) ? CarbonImmutable::createFromTimestampUTC($pos['t']) : null,
            );
        })->all();
    }

    /**
     * @param  array<string, mixed>  $params
     * @return array<string, mixed>
     */
    private function call(string $service, array $params, ?string $sessionId = null): array
    {
        $query = ['svc' => $service, 'params' => json_encode($params)];
        if ($sessionId !== null) {
            $query['sid'] = $sessionId;
        }

        try {
            $response = Http::timeout(10)->get("{$this->baseUrl}/wialon/ajax.html", $query);
        } catch (Throwable $e) {
            throw new GpsProviderException("Could not reach Wialon: {$e->getMessage()}", previous: $e);
        }

        if ($response->failed()) {
            throw new GpsProviderException("Wialon returned an unexpected response (HTTP {$response->status()}).");
        }

        $body = $response->json();

        if (! is_array($body)) {
            throw new GpsProviderException('Wialon returned an unreadable response.');
        }

        // Wialon signals errors via a top-level `error` code (e.g. 1 =
        // invalid session, 4 = invalid credentials, 8 = invalid token)
        // rather than an HTTP status — a 200 with {"error": 8} is how a
        // bad token actually comes back. token/login's own bad-token case
        // is handled by login() with a clearer message instead (it checks
        // for a missing `eid`, not this generic one); logout is
        // best-effort cleanup and never worth failing the caller over.
        if (isset($body['error']) && ! in_array($service, ['token/login', 'core/logout'], true)) {
            throw new GpsProviderException("Wialon error {$body['error']}.");
        }

        return $body;
    }
}
