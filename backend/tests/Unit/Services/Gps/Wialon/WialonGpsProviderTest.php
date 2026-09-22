<?php

namespace Tests\Unit\Services\Gps\Wialon;

use App\Services\Gps\GpsProviderException;
use App\Services\Gps\Wialon\WialonGpsProvider;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Exercises WialonGpsProvider against faked HTTP responses shaped like
 * Wialon's real API (a single RPC endpoint keyed by `svc`) — there's no
 * real Wialon account to test against (WIALON_TOKEN is unset, same
 * graceful-degradation-for-missing-credentials pattern as SMS/Maps in
 * earlier phases), so this is the strongest verification available for
 * this class's own request/response handling.
 */
class WialonGpsProviderTest extends TestCase
{
    private function svcOf(Request $request): ?string
    {
        parse_str((string) parse_url($request->url(), PHP_URL_QUERY), $query);

        return $query['svc'] ?? null;
    }

    public function test_lists_units_with_their_last_known_position(): void
    {
        Http::fake(function (Request $request) {
            return match ($this->svcOf($request)) {
                'token/login' => Http::response(['eid' => 'session-123']),
                'core/search_items' => Http::response([
                    'items' => [
                        ['id' => 1001, 'nm' => 'T 123 ABC', 'pos' => ['y' => -6.8161, 'x' => 39.2803, 'c' => 90, 's' => 62, 't' => 1700000000]],
                        ['id' => 1002, 'nm' => 'T 456 XYZ'], // no `pos` at all — never reported.
                    ],
                ]),
                'core/logout' => Http::response(['error' => 0]),
                default => Http::response([], 404),
            };
        });

        $units = (new WialonGpsProvider('https://hst-api.wialon.com'))->listUnits('a-real-token');

        $this->assertCount(2, $units);
        $this->assertSame('1001', $units[0]->unitId);
        $this->assertSame('T 123 ABC', $units[0]->name);
        $this->assertTrue($units[0]->hasPosition());
        $this->assertSame(-6.8161, $units[0]->lat);
        $this->assertSame(39.2803, $units[0]->lng);
        $this->assertSame(90.0, $units[0]->heading);
        $this->assertSame(62.0, $units[0]->speedKmh);
        $this->assertNotNull($units[0]->recordedAt);

        $this->assertFalse($units[1]->hasPosition());
    }

    /**
     * Wialon's unit list has no driver field of its own, so a driver typed
     * into the unit name is the only one there is — same convention every
     * provider here now reads (see DeviceNameParser).
     */
    public function test_reads_a_driver_name_out_of_the_unit_name(): void
    {
        Http::fake(function (Request $request) {
            return match ($this->svcOf($request)) {
                'token/login' => Http::response(['eid' => 'session-123']),
                'core/search_items' => Http::response([
                    'items' => [
                        ['id' => 1001, 'nm' => 'T579EKP MWINYI'],
                        // A plate written with spaces — its own tail must
                        // never come back as a driver's name.
                        ['id' => 1002, 'nm' => 'T 456 XYZ'],
                    ],
                ]),
                'core/logout' => Http::response(['error' => 0]),
                default => Http::response([], 404),
            };
        });

        $units = (new WialonGpsProvider('https://hst-api.wialon.com'))->listUnits('a-real-token');

        $this->assertSame('MWINYI', $units[0]->driverName);
        $this->assertNull($units[1]->driverName);
    }

    public function test_an_invalid_token_throws_a_clear_exception(): void
    {
        Http::fake(fn (Request $request) => Http::response(['error' => 8]));

        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Wialon rejected this API token.');

        (new WialonGpsProvider('https://hst-api.wialon.com'))->listUnits('a-bad-token');
    }

    public function test_an_unreachable_provider_throws_a_gps_provider_exception(): void
    {
        Http::fake(fn (Request $request) => throw new ConnectionException('Connection timed out'));

        $this->expectException(GpsProviderException::class);

        (new WialonGpsProvider('https://hst-api.wialon.com'))->listUnits('a-real-token');
    }
}
