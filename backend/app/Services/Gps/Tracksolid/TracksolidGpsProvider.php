<?php

namespace App\Services\Gps\Tracksolid;

use App\Services\Gps\GpsProvider;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsUnit;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Tracksolid Pro's Open Platform API (openapi.tracksolid.com) — the third
 * provider named alongside Wialon and Traccar. Flagged more cautiously
 * than either of those two: Wialon and Traccar both publish a plain,
 * stable REST/RPC surface anyone can read without an account, but
 * Tracksolid's Open Platform is account-gated (a business-tier API
 * agreement, not just a signup) and normally authenticates whole requests
 * with an appKey/appSecret HMAC signature rather than a single bearer
 * value — this class models the simpler case where a company has already
 * exchanged those for a long-lived `access_token` in their own Tracksolid
 * account (matching the single-pasted-string shape every other provider
 * here uses), since that is the only way this fits the app's "connect
 * with one token" UX at all. Endpoint paths and field names below are a
 * best-effort model of Tracksolid's publicly described Open Platform
 * shape, not verified against a real account (none exists in this
 * environment) — this is the least-confident of the three integrations;
 * confirm every path/field against a real Tracksolid Open Platform
 * account before this ever carries production traffic, same caveat
 * SelcomMobileMoneyGateway already carries for the same reason.
 */
class TracksolidGpsProvider implements GpsProvider
{
    public function __construct(private readonly ?string $baseUrl) {}

    public function listUnits(string $accessToken): array
    {
        if (blank($this->baseUrl)) {
            throw new GpsProviderException('Tracksolid is not configured on this server (set TRACKSOLID_BASE_URL).');
        }

        $devices = $this->get('/device/list', $accessToken);

        return collect($devices)->map(function (array $device) {
            return new GpsUnit(
                unitId: (string) ($device['imei'] ?? $device['deviceId']),
                name: (string) ($device['name'] ?? $device['imei'] ?? $device['deviceId']),
                lat: $device['lat'] ?? null,
                lng: $device['lng'] ?? null,
                heading: $device['course'] ?? null,
                recordedAt: isset($device['gpsTime']) ? CarbonImmutable::parse($device['gpsTime']) : null,
                speedKmh: isset($device['speed']) ? (float) $device['speed'] : null,
            );
        })->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function get(string $path, string $accessToken): array
    {
        try {
            $response = Http::timeout(10)
                ->withToken($accessToken)
                ->get("{$this->baseUrl}/openapi{$path}");
        } catch (Throwable $e) {
            throw new GpsProviderException("Could not reach Tracksolid: {$e->getMessage()}", previous: $e);
        }

        if ($response->status() === 401) {
            throw new GpsProviderException('Tracksolid rejected this API token. Check it and try again.');
        }

        if ($response->failed()) {
            throw new GpsProviderException("Tracksolid returned an unexpected response (HTTP {$response->status()}).");
        }

        $body = $response->json();

        // Tracksolid's Open Platform wraps every response in a
        // {code, message, data} envelope rather than returning the list
        // directly — a non-zero `code` signals an application-level error
        // even on a 200 HTTP response, the same shape Selcom's gateway
        // also has to account for.
        if (! is_array($body)) {
            throw new GpsProviderException('Tracksolid returned an unreadable response.');
        }

        if (($body['code'] ?? 0) !== 0) {
            throw new GpsProviderException('Tracksolid error: '.($body['message'] ?? 'unknown error'));
        }

        return $body['data'] ?? [];
    }
}
