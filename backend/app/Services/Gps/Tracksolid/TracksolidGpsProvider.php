<?php

namespace App\Services\Gps\Tracksolid;

use App\Services\Gps\DeviceNameParser;
use App\Services\Gps\GpsProvider;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsUnit;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Tracksolid Pro / JIMI IoT's real Open Platform API
 * (https://tracksolidprodocs.jimicloud.com), replacing an earlier
 * best-effort model that assumed a plain bearer-token REST surface —
 * confirmed wrong by testing against a real demo account (JIMI IoT,
 * 2026-09-17): the real API is a single JSON-RPC-style endpoint
 * (dispatch by a `method` request parameter), and every single call —
 * including the very first one — must be signed with an appKey/appSecret
 * pair, not just carry a bearer token.
 *
 * Credential shape: unlike Wialon/Traccar's one pasted token, Tracksolid
 * ties an appKey+appSecret pair to one specific Tracksolid account (JIMI
 * issues them together when you "apply" for API access), and getting an
 * actual access_token additionally needs that account's own login
 * (`user_id` + the MD5 of its password) signed with that same pair. All
 * four pieces are required, so the `access_token` this class receives is
 * really a colon-packed credential bundle —
 * `appKey:appSecret:account:userPwdMd5` — not a literal access token, to
 * fit the app's existing "one pasted string per connection" shape without
 * changing the shared GpsProvider interface. A real dedicated 4-field
 * Connect GPS form for this one provider would be a nicer follow-up.
 *
 * Region: this account's appKey only validated against the HK/SG node
 * (`hk-open.tracksolidpro.com`) — TS/EU/US nodes all rejected it with
 * "invalid AppKey" — confirming an appKey is tied to one specific
 * regional node, not global. `TRACKSOLID_BASE_URL` is therefore one
 * fixed, server-wide region for this whole deployment; if a future
 * customer's account lives on a different node, that's an ops config
 * change (or, if genuinely needed, the region would have to become a 5th
 * piece of the packed credential bundle).
 */
class TracksolidGpsProvider implements GpsProvider
{
    public function __construct(private readonly ?string $baseUrl) {}

    public function listUnits(string $accessToken): array
    {
        if (blank($this->baseUrl)) {
            throw new GpsProviderException('Tracksolid is not configured on this server (set TRACKSOLID_BASE_URL).');
        }

        [$appKey, $appSecret, $account, $userPwdMd5] = $this->parseCredentialBundle($accessToken);
        $cacheKey = $this->tokenCacheKey($appKey, $account);

        $token = Cache::get($cacheKey);
        if (! is_string($token)) {
            $token = $this->fetchAndCacheAccessToken($appKey, $appSecret, $account, $userPwdMd5, $cacheKey);
        }

        try {
            $devices = $this->call('jimi.user.device.list', [
                'access_token' => $token,
                'target' => $account,
            ], $appKey, $appSecret);

            $positions = $this->call('jimi.user.device.location.list', [
                'access_token' => $token,
                'target' => $account,
            ], $appKey, $appSecret);
        } catch (GpsProviderException $e) {
            // The cached token may be the one Tracksolid just rejected —
            // forget it so the *next* poll cycle re-authenticates instead
            // of retrying the same bad value for the rest of its TTL. Not
            // retried inline here: a real rate-limit error (this app's own
            // observed failure mode — see PollGpsPositionsJob's docblock)
            // would only get worse from an immediate second attempt.
            Cache::forget($cacheKey);

            throw $e;
        }

        $positionsByImei = collect($positions)->keyBy('imei');

        return collect($devices)->map(function (array $device) use ($positionsByImei) {
            $imei = (string) $device['imei'];
            $position = $positionsByImei->get($imei);
            // The plate (vehicleNumber), not the device's own model/serial
            // name, is what suggestTruckMatch() actually needs to line up
            // against a truck's registration_number.
            $vehicleNumber = (string) ($device['vehicleNumber'] ?? '');
            $name = (string) ($vehicleNumber !== '' ? $vehicleNumber : ($device['deviceName'] ?? $imei));
            $driverName = trim((string) ($device['driverName'] ?? ''));

            // Confirmed against this account's real fleet: most devices
            // never use Tracksolid's own dedicated driver field OR its
            // vehicleNumber field at all — the plate and driver are typed
            // straight into deviceName instead (e.g. deviceName
            // "T579EKP MWINYI" with vehicleNumber left blank), so $name
            // (whichever of the two it resolved to above) is what actually
            // needs parsing, not vehicleNumber specifically. Safe to do
            // unconditionally: DeviceNameParser only treats a space/dot-
            // separated remainder as a driver name, so a bare serial like
            // "AT4-SERIAL" or a raw IMEI correctly yields no driver at all.
            if ($driverName === '') {
                $driverName = DeviceNameParser::parse($name)['driverName'] ?? '';
            }

            return new GpsUnit(
                unitId: $imei,
                name: $name,
                lat: $position['lat'] ?? null,
                lng: $position['lng'] ?? null,
                heading: isset($position['direction']) ? (float) $position['direction'] : null,
                recordedAt: isset($position['gpsTime']) ? CarbonImmutable::parse($position['gpsTime']) : null,
                speedKmh: isset($position['speed']) ? (float) $position['speed'] : null,
                driverName: $driverName !== '' ? $driverName : null,
            );
        })->all();
    }

    /**
     * @return array{0: string, 1: string, 2: string, 3: string}
     */
    private function parseCredentialBundle(string $accessToken): array
    {
        $parts = explode(':', $accessToken);

        if (count($parts) !== 4 || in_array('', $parts, true)) {
            throw new GpsProviderException(
                'Tracksolid needs all four credentials in one field: appKey:appSecret:account:userPwdMd5.'
            );
        }

        return $parts;
    }

    /**
     * Cache key scoped to appKey+account (not the whole packed bundle,
     * which also carries the account's password hash — no reason for that
     * to end up as a cache key string, however unlikely a leak is).
     */
    private function tokenCacheKey(string $appKey, string $account): string
    {
        return 'gps:tracksolid:access_token:'.md5($appKey.':'.$account);
    }

    /**
     * A fresh jimi.oauth.token.get call is one of only three requests this
     * class ever makes per poll cycle — doing it every single minute (the
     * scheduled poll cadence) rather than reusing the token for its real
     * ~2-hour life is exactly the kind of avoidable load that a real
     * account hit "Illegal access, request frequency is too high" over
     * (see PollGpsPositionsJob's own docblock for the live incident this
     * fixes). Cached for comfortably less than the provider's own
     * expiresIn so a request is never made with a token already expired
     * provider-side.
     */
    private function fetchAndCacheAccessToken(string $appKey, string $appSecret, string $account, string $userPwdMd5, string $cacheKey): string
    {
        $result = $this->call('jimi.oauth.token.get', [
            'user_id' => $account,
            'user_pwd_md5' => $userPwdMd5,
            'expires_in' => 7200,
        ], $appKey, $appSecret, expectEnvelope: false);

        $token = $result['accessToken'] ?? null;

        if (! is_string($token) || $token === '') {
            throw new GpsProviderException('Tracksolid did not return an access token.');
        }

        $expiresIn = is_int($result['expiresIn'] ?? null) ? $result['expiresIn'] : 7200;
        $safetyMarginSeconds = 300;
        Cache::put($cacheKey, $token, max(60, $expiresIn - $safetyMarginSeconds));

        return $token;
    }

    /**
     * One signed call to Tracksolid's single JSON-RPC-style endpoint —
     * every request (the initial token exchange included) is dispatched
     * by a `method` parameter and must carry a valid `sign`, not just the
     * data calls. When `expectEnvelope` is true (every call except the
     * token exchange) this returns `result` already unwrapped, matching
     * the shape `listUnits()`'s callers expect; the token exchange needs
     * its own richer `result` object instead.
     *
     * @return array<string, mixed>|array<int, array<string, mixed>>
     */
    private function call(string $method, array $privateParams, string $appKey, string $appSecret, bool $expectEnvelope = true): array
    {
        $common = [
            'method' => $method,
            'timestamp' => gmdate('Y-m-d H:i:s'),
            'app_key' => $appKey,
            'sign_method' => 'md5',
            'v' => '1.0',
            'format' => 'json',
        ];
        $params = array_merge($common, $privateParams);
        $params['sign'] = $this->sign($params, $appSecret);

        try {
            $response = Http::asForm()->timeout(10)->post($this->baseUrl, $params);
        } catch (Throwable $e) {
            throw new GpsProviderException("Could not reach Tracksolid: {$e->getMessage()}", previous: $e);
        }

        if ($response->failed()) {
            throw new GpsProviderException("Tracksolid returned an unexpected response (HTTP {$response->status()}).");
        }

        $body = $response->json();

        if (! is_array($body)) {
            throw new GpsProviderException('Tracksolid returned an unreadable response.');
        }

        $code = $body['code'] ?? -1;

        if ($code === 1004) {
            throw new GpsProviderException('Tracksolid rejected this API token. Check it and try again.');
        }

        if ($code !== 0) {
            throw new GpsProviderException('Tracksolid error: '.($body['message'] ?? 'unknown error'));
        }

        $result = $body['result'] ?? ($expectEnvelope ? [] : null);

        return is_array($result) ? $result : [];
    }

    /**
     * Sort every request parameter (excluding `sign` itself) alphabetically
     * by key, concatenate as key+value with no separators, wrap the whole
     * thing in the appSecret on both sides, then MD5 and uppercase — the
     * exact algorithm from https://tracksolidprodocs.jimicloud.com's
     * "Signature" section, confirmed byte-for-byte against a real account
     * (a wrong signature is silently rejected, not descriptively erred).
     */
    private function sign(array $params, string $appSecret): string
    {
        ksort($params);
        $concatenated = '';
        foreach ($params as $key => $value) {
            $concatenated .= $key.$value;
        }

        return strtoupper(md5($appSecret.$concatenated.$appSecret));
    }
}
