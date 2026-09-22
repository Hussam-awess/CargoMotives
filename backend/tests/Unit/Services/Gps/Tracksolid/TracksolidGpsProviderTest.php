<?php

namespace Tests\Unit\Services\Gps\Tracksolid;

use App\Services\Gps\GpsProviderException;
use App\Services\Gps\Tracksolid\TracksolidGpsProvider;
use GuzzleHttp\Promise\PromiseInterface;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Exercises TracksolidGpsProvider against faked HTTP responses shaped like
 * the REAL JIMI IoT / Tracksolid Pro Open Platform API — confirmed against
 * a real demo account on 2026-09-17 (see the class's own docblock): one
 * signed JSON-RPC-style endpoint dispatched by a `method` form field, not
 * the plain bearer-token REST surface an earlier, unverified version of
 * this class assumed.
 */
class TracksolidGpsProviderTest extends TestCase
{
    private const VALID_BUNDLE = 'app-key-123:app-secret-456:JIMI_IOT:pwdmd5hash';

    protected function setUp(): void
    {
        parent::setUp();

        // The access-token cache is keyed by appKey+account, not per test —
        // without this, a token cached by an earlier test would silently
        // make a later test's "was jimi.oauth.token.get called" assertion
        // meaningless.
        Cache::flush();
    }

    public function test_lists_units_by_exchanging_a_token_and_combining_device_and_location_data(): void
    {
        Http::fake(fn (Request $request) => $this->respondByMethod($request));

        $units = (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))
            ->listUnits(self::VALID_BUNDLE);

        $this->assertCount(2, $units);

        $this->assertSame('123456789012345', $units[0]->unitId);
        // The plate (vehicleNumber), not the device's own model/serial name.
        $this->assertSame('T 123 ABC', $units[0]->name);
        $this->assertTrue($units[0]->hasPosition());
        $this->assertSame(-6.8161, $units[0]->lat);
        $this->assertSame(39.2803, $units[0]->lng);
        $this->assertSame(90.0, $units[0]->heading);
        $this->assertSame(55.2, $units[0]->speedKmh);
        $this->assertNotNull($units[0]->recordedAt);
        $this->assertSame('JOSEFAT MGOSI', $units[0]->driverName);

        // No vehicleNumber, no driverName field at all, and no matching
        // location entry — a device Tracksolid never reported one for.
        $this->assertSame('987654321098765', $units[1]->unitId);
        $this->assertSame('AT4-SERIAL', $units[1]->name);
        $this->assertFalse($units[1]->hasPosition());
        $this->assertNull($units[1]->driverName);
    }

    public function test_every_request_is_signed_and_dispatched_by_method(): void
    {
        Http::fake(fn (Request $request) => $this->respondByMethod($request));

        (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))
            ->listUnits(self::VALID_BUNDLE);

        Http::assertSent(function (Request $request) {
            $data = $request->data();

            return $data['method'] === 'jimi.oauth.token.get'
                && $data['app_key'] === 'app-key-123'
                && $data['user_id'] === 'JIMI_IOT'
                && $data['user_pwd_md5'] === 'pwdmd5hash'
                && ! empty($data['sign']);
        });

        Http::assertSent(function (Request $request) {
            $data = $request->data();

            return $data['method'] === 'jimi.user.device.list'
                && $data['target'] === 'JIMI_IOT'
                && $data['access_token'] === 'a-real-access-token';
        });
    }

    /**
     * The real regression this fixes: fetching a brand new access token on
     * every single poll (every scheduled minute) rather than reusing it for
     * its ~2-hour life is exactly the kind of avoidable load a real account
     * hit "Illegal access, request frequency is too high" over — see
     * PollGpsPositionsJob's own docblock for the live incident.
     */
    public function test_reuses_a_cached_access_token_instead_of_re_authenticating_every_call(): void
    {
        Http::fake(fn (Request $request) => $this->respondByMethod($request));
        $provider = new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest');

        $provider->listUnits(self::VALID_BUNDLE);
        $provider->listUnits(self::VALID_BUNDLE);

        Http::assertSentCount(5); // 1 token exchange + 2×(device list + location list)
    }

    public function test_a_different_account_gets_its_own_cached_token(): void
    {
        Http::fake(fn (Request $request) => $this->respondByMethod($request));
        $provider = new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest');

        $provider->listUnits(self::VALID_BUNDLE);
        $provider->listUnits('app-key-999:app-secret-999:OTHER_ACCOUNT:otherpwdmd5');

        Http::assertSentCount(6); // 2 separate token exchanges, one per account
    }

    public function test_forgets_the_cached_token_after_a_failed_call_so_the_next_poll_re_authenticates(): void
    {
        // The device-list call fails exactly once (a stand-in for the real
        // rate-limit error this fixes) — every other call, including the
        // second listUnits()'s own device-list retry, succeeds normally.
        $deviceListFailuresLeft = 1;
        Http::fake(function (Request $request) use (&$deviceListFailuresLeft) {
            $method = $request->data()['method'] ?? null;
            if ($method === 'jimi.user.device.list' && $deviceListFailuresLeft > 0) {
                $deviceListFailuresLeft--;

                return Http::response(['code' => 1001, 'message' => 'Illegal access, request frequency is too high']);
            }

            return $this->respondByMethod($request);
        });
        $provider = new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest');

        try {
            $provider->listUnits(self::VALID_BUNDLE);
            $this->fail('Expected the first call to throw.');
        } catch (GpsProviderException) {
            // Expected — the stubbed device-list failure above.
        }

        $tokenCallsBefore = collect(Http::recorded())
            ->filter(fn (array $pair) => ($pair[0]->data()['method'] ?? null) === 'jimi.oauth.token.get')
            ->count();

        $provider->listUnits(self::VALID_BUNDLE);

        $tokenCallsAfter = collect(Http::recorded())
            ->filter(fn (array $pair) => ($pair[0]->data()['method'] ?? null) === 'jimi.oauth.token.get')
            ->count();

        // A second token exchange — proving the failed first call forgot
        // the cached token instead of leaving the second call to retry the
        // exact same (possibly bad) cached value.
        $this->assertSame($tokenCallsBefore + 1, $tokenCallsAfter);
    }

    /**
     * The real, confirmed pattern across this account's actual fleet: most
     * devices never fill in Tracksolid's own vehicleNumber or driverName
     * fields at all — both are blank, and the plate + driver are typed
     * straight into deviceName instead (e.g. "T579EKP MWINYI"), which the
     * app was previously discarding entirely (only the leading plate was
     * ever extracted, at import time only).
     */
    public function test_falls_back_to_parsing_the_driver_name_out_of_device_name_when_vehicle_number_and_driver_name_are_both_blank(): void
    {
        Http::fake(fn (Request $request) => match ($request->data()['method'] ?? null) {
            'jimi.oauth.token.get' => Http::response(['code' => 0, 'result' => ['accessToken' => 'tok', 'expiresIn' => 7200]]),
            'jimi.user.device.list' => Http::response(['code' => 0, 'result' => [
                ['imei' => '111', 'deviceName' => 'T579EKP MWINYI', 'vehicleNumber' => ''],
            ]]),
            'jimi.user.device.location.list' => Http::response(['code' => 0, 'result' => []]),
            default => Http::response(['code' => 1001], 500),
        });

        $units = (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))->listUnits(self::VALID_BUNDLE);

        $this->assertSame('MWINYI', $units[0]->driverName);
    }

    public function test_the_dedicated_driver_field_wins_over_a_name_parsed_fallback_when_both_are_present(): void
    {
        Http::fake(fn (Request $request) => match ($request->data()['method'] ?? null) {
            'jimi.oauth.token.get' => Http::response(['code' => 0, 'result' => ['accessToken' => 'tok', 'expiresIn' => 7200]]),
            'jimi.user.device.list' => Http::response(['code' => 0, 'result' => [
                ['imei' => '111', 'deviceName' => 'T579EKP MWINYI', 'vehicleNumber' => '', 'driverName' => 'The Real Driver'],
            ]]),
            'jimi.user.device.location.list' => Http::response(['code' => 0, 'result' => []]),
            default => Http::response(['code' => 1001], 500),
        });

        $units = (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))->listUnits(self::VALID_BUNDLE);

        $this->assertSame('The Real Driver', $units[0]->driverName);
    }

    /**
     * A bare device serial/model name ("AT4-SERIAL", a real device on this
     * account) must never be misread as a driver name just because it's
     * the only name available.
     */
    public function test_a_bare_serial_number_device_name_yields_no_driver(): void
    {
        Http::fake(fn (Request $request) => match ($request->data()['method'] ?? null) {
            'jimi.oauth.token.get' => Http::response(['code' => 0, 'result' => ['accessToken' => 'tok', 'expiresIn' => 7200]]),
            'jimi.user.device.list' => Http::response(['code' => 0, 'result' => [
                ['imei' => '111', 'deviceName' => 'AT4-SERIAL', 'vehicleNumber' => ''],
            ]]),
            'jimi.user.device.location.list' => Http::response(['code' => 0, 'result' => []]),
            default => Http::response(['code' => 1001], 500),
        });

        $units = (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))->listUnits(self::VALID_BUNDLE);

        $this->assertNull($units[0]->driverName);
    }

    public function test_a_malformed_credential_bundle_throws_a_clear_exception(): void
    {
        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Tracksolid needs all four credentials in one field');

        (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))
            ->listUnits('not-enough-parts');
    }

    public function test_an_invalid_credential_bundle_at_the_provider_throws_a_clear_exception(): void
    {
        Http::fake(fn () => Http::response(['code' => 1004, 'message' => 'Illegal access, token exception!']));

        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Tracksolid rejected this API token. Check it and try again.');

        (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))
            ->listUnits(self::VALID_BUNDLE);
    }

    public function test_an_application_level_error_throws_a_clear_exception(): void
    {
        Http::fake(fn () => Http::response(['code' => 1001, 'message' => 'Parameter error']));

        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Tracksolid error: Parameter error');

        (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))
            ->listUnits(self::VALID_BUNDLE);
    }

    public function test_an_unreachable_provider_throws_a_gps_provider_exception(): void
    {
        Http::fake(fn (Request $request) => throw new ConnectionException('Connection timed out'));

        $this->expectException(GpsProviderException::class);

        (new TracksolidGpsProvider('https://hk-open.tracksolidpro.com/route/rest'))
            ->listUnits(self::VALID_BUNDLE);
    }

    public function test_an_unconfigured_base_url_throws_a_clear_exception(): void
    {
        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Tracksolid is not configured on this server (set TRACKSOLID_BASE_URL).');

        (new TracksolidGpsProvider(null))->listUnits(self::VALID_BUNDLE);
    }

    private function respondByMethod(Request $request): PromiseInterface
    {
        $method = $request->data()['method'] ?? null;

        return match ($method) {
            'jimi.oauth.token.get' => Http::response([
                'code' => 0,
                'message' => 'success',
                'result' => ['accessToken' => 'a-real-access-token', 'expiresIn' => 7200],
            ]),
            'jimi.user.device.list' => Http::response([
                'code' => 0,
                'message' => 'success',
                'result' => [
                    ['imei' => '123456789012345', 'deviceName' => 'VL802-SERIAL', 'vehicleNumber' => 'T 123 ABC', 'driverName' => 'JOSEFAT MGOSI'],
                    ['imei' => '987654321098765', 'deviceName' => 'AT4-SERIAL', 'vehicleNumber' => ''],
                ],
            ]),
            'jimi.user.device.location.list' => Http::response([
                'code' => 0,
                'message' => 'success',
                'result' => [
                    ['imei' => '123456789012345', 'lat' => -6.8161, 'lng' => 39.2803, 'direction' => 90, 'speed' => 55.2, 'gpsTime' => '2026-01-01 10:00:00'],
                    // 987654321098765 never reported — no entry at all.
                ],
            ]),
            default => Http::response(['code' => 1001, 'message' => 'unknown method in test'], 500),
        };
    }
}
