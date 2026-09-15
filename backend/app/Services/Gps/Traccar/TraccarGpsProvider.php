<?php

namespace App\Services\Gps\Traccar;

use App\Services\Gps\GpsProvider;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsUnit;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Traccar's REST API (https://www.traccar.org/api-reference) — the second
 * provider this app's "prove the pattern, then add the next one as its own
 * concrete class" plan (see WialonGpsProvider's docblock) calls for.
 *
 * Unlike Wialon's single RPC endpoint, Traccar exposes plain resource
 * routes and accepts a user's own long-lived API token as a `token` query
 * parameter on any of them (Settings → the user's own page → "Token", a
 * real, documented Traccar feature) — so this still fits the one-pasted-
 * string `listUnits(string $accessToken)` contract every other provider
 * here uses, with no separate login/session step needed.
 *
 * Two calls are combined into one GpsUnit list: `/api/devices` (id, name)
 * and `/api/positions` (the latest position per device, keyed by
 * deviceId) — Traccar has no single endpoint returning both together the
 * way Wialon's `flags=1025` does.
 */
class TraccarGpsProvider implements GpsProvider
{
    public function __construct(private readonly ?string $baseUrl) {}

    public function listUnits(string $accessToken): array
    {
        if (blank($this->baseUrl)) {
            throw new GpsProviderException('Traccar is not configured on this server (set TRACCAR_BASE_URL).');
        }

        $devices = $this->get('/api/devices', $accessToken);
        $positions = $this->get('/api/positions', $accessToken);

        $positionsByDeviceId = collect($positions)->keyBy('deviceId');

        return collect($devices)->map(function (array $device) use ($positionsByDeviceId) {
            $position = $positionsByDeviceId->get($device['id']);

            return new GpsUnit(
                unitId: (string) $device['id'],
                name: (string) ($device['name'] ?? $device['uniqueId'] ?? $device['id']),
                lat: $position['latitude'] ?? null,
                lng: $position['longitude'] ?? null,
                heading: $position['course'] ?? null,
                recordedAt: isset($position['fixTime']) ? CarbonImmutable::parse($position['fixTime']) : null,
                // Traccar reports speed in knots, not km/h — 1 knot = 1.852 km/h.
                speedKmh: isset($position['speed']) ? (float) $position['speed'] * 1.852 : null,
            );
        })->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function get(string $path, string $accessToken): array
    {
        try {
            $response = Http::timeout(10)->get("{$this->baseUrl}{$path}", ['token' => $accessToken]);
        } catch (Throwable $e) {
            throw new GpsProviderException("Could not reach Traccar: {$e->getMessage()}", previous: $e);
        }

        if ($response->status() === 401) {
            throw new GpsProviderException('Traccar rejected this API token. Check it and try again.');
        }

        if ($response->failed()) {
            throw new GpsProviderException("Traccar returned an unexpected response (HTTP {$response->status()}).");
        }

        $body = $response->json();

        if (! is_array($body)) {
            throw new GpsProviderException('Traccar returned an unreadable response.');
        }

        return $body;
    }
}
