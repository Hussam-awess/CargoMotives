<?php

namespace Tests\Unit\Services\Gps\Traccar;

use App\Services\Gps\GpsProviderException;
use App\Services\Gps\Traccar\TraccarGpsProvider;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Exercises TraccarGpsProvider against faked HTTP responses shaped like
 * Traccar's real REST API (plain /api/devices + /api/positions resource
 * routes, a `token` query param) — there's no real Traccar server to test
 * against here, same graceful-degradation-for-missing-credentials pattern
 * as WialonGpsProviderTest.
 */
class TraccarGpsProviderTest extends TestCase
{
    public function test_lists_units_by_combining_devices_and_positions(): void
    {
        Http::fake(function (Request $request) {
            return match (true) {
                str_contains($request->url(), '/api/devices') => Http::response([
                    ['id' => 1, 'name' => 'T 123 ABC', 'uniqueId' => 'imei-1'],
                    ['id' => 2, 'name' => 'T 456 XYZ', 'uniqueId' => 'imei-2'],
                ]),
                str_contains($request->url(), '/api/positions') => Http::response([
                    ['deviceId' => 1, 'latitude' => -6.8161, 'longitude' => 39.2803, 'course' => 90, 'speed' => 33.5, 'fixTime' => '2026-01-01T10:00:00Z'],
                    // device 2 has no position at all — never reported.
                ]),
                default => Http::response([], 404),
            };
        });

        $units = (new TraccarGpsProvider('https://traccar.example.com'))->listUnits('a-real-token');

        $this->assertCount(2, $units);
        $this->assertSame('1', $units[0]->unitId);
        $this->assertSame('T 123 ABC', $units[0]->name);
        $this->assertTrue($units[0]->hasPosition());
        $this->assertSame(-6.8161, $units[0]->lat);
        $this->assertSame(39.2803, $units[0]->lng);
        $this->assertSame(90.0, $units[0]->heading);
        // Traccar reports speed in knots — 33.5 knots * 1.852 = 62.042 km/h.
        $this->assertEqualsWithDelta(62.042, $units[0]->speedKmh, 0.001);
        $this->assertNotNull($units[0]->recordedAt);

        $this->assertFalse($units[1]->hasPosition());
    }

    public function test_an_invalid_token_throws_a_clear_exception(): void
    {
        Http::fake(fn (Request $request) => Http::response(['error' => 'Unauthorized'], 401));

        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Traccar rejected this API token.');

        (new TraccarGpsProvider('https://traccar.example.com'))->listUnits('a-bad-token');
    }

    public function test_an_unreachable_provider_throws_a_gps_provider_exception(): void
    {
        Http::fake(fn (Request $request) => throw new ConnectionException('Connection timed out'));

        $this->expectException(GpsProviderException::class);

        (new TraccarGpsProvider('https://traccar.example.com'))->listUnits('a-real-token');
    }

    public function test_an_unconfigured_base_url_throws_a_clear_exception(): void
    {
        $this->expectException(GpsProviderException::class);
        $this->expectExceptionMessage('Traccar is not configured on this server (set TRACCAR_BASE_URL).');

        (new TraccarGpsProvider(null))->listUnits('a-real-token');
    }
}
