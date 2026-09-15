<?php

namespace Tests\Unit\Services\Gps\Tracksolid;

use App\Services\Gps\GpsProviderException;
use App\Services\Gps\Tracksolid\TracksolidGpsProvider;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Exercises TracksolidGpsProvider against faked HTTP responses shaped like
 * Tracksolid's publicly described Open Platform API — see that class's own
 * docblock for why this integration is the least-confident of the three
 * GPS providers (no real account exists anywhere to verify the exact
 * wire shape against).
 */
class TracksolidGpsProviderTest extends TestCase
{
    public function test_lists_units_from_the_device_list_endpoint(): void
    {
        Http::fake(fn (Request $request) => Http::response([
            'code' => 0,
            'message' => 'ok',
            'data' => [
                ['imei' => '123456789012345', 'name' => 'T 123 ABC', 'lat' => -6.8161, 'lng' => 39.2803, 'course' => 90, 'speed' => 55.2, 'gpsTime' => '2026-01-01 10:00:00'],
                ['imei' => '987654321098765', 'name' => 'T 456 XYZ'], // no position fields at all.
            ],
        ]));

        $units = (new TracksolidGpsProvider('https://openapi.tracksolid.com'))->listUnits('a-real-token');

        $this->assertCount(2, $units);
        $this->assertSame('123456789012345', $units[0]->unitId);
        $this->assertSame('T 123 ABC', $units[0]->name);
        $this->assertTrue($units[0]->hasPosition());
        $this->assertSame(-6.8161, $units[0]->lat);
        $this->assertSame(39.2803, $units[0]->lng);
        $this->assertSame(90.0, $units[0]->heading);
        $this->assertSame(55.2, $units[0]->speedKmh);
        $this->assertNotNull($units[0]->recordedAt);

        $this->assertFalse($units[1]->hasPosition());
    }

    public function test_an_application_level_error_throws_a_clear_exception(): void
    {
        Http::fake(fn (Request $request) => Http::response(['code' => 40001, 'message' => 'invalid access_token']));

        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Tracksolid error: invalid access_token');

        (new TracksolidGpsProvider('https://openapi.tracksolid.com'))->listUnits('a-bad-token');
    }

    public function test_an_unreachable_provider_throws_a_gps_provider_exception(): void
    {
        Http::fake(fn (Request $request) => throw new ConnectionException('Connection timed out'));

        $this->expectException(GpsProviderException::class);

        (new TracksolidGpsProvider('https://openapi.tracksolid.com'))->listUnits('a-real-token');
    }

    public function test_an_unconfigured_base_url_throws_a_clear_exception(): void
    {
        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Tracksolid is not configured on this server (set TRACKSOLID_BASE_URL).');

        (new TracksolidGpsProvider(null))->listUnits('a-real-token');
    }
}
