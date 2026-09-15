<?php

namespace Tests\Unit\Jobs;

use App\Jobs\NormalizeGpsPositionJob;
use App\Jobs\PollGpsPositionsJob;
use App\Models\GpsConnection;
use App\Models\Truck;
use App\Services\Gps\GpsProvider;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsProviderManager;
use App\Services\Gps\GpsUnit;
use App\Services\Gps\Wialon\WialonGpsProvider;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use RuntimeException;
use Tests\TestCase;

/**
 * The "poll" stage of the async GPS pipeline (TRD §5.2). Uses a fake
 * GpsProvider bound in the container (not Http::fake against Wialon
 * directly) since this job's own job-dispatch and failure-isolation logic
 * is what's under test here — WialonGpsProviderTest already covers the
 * real HTTP shape.
 */
class PollGpsPositionsJobTest extends TestCase
{
    use RefreshDatabase;

    public function test_dispatches_a_normalize_job_for_each_matched_unit_with_a_position(): void
    {
        Bus::fake();

        $connection = GpsConnection::factory()->create(['provider' => 'wialon', 'status' => 'connected']);
        $truck = Truck::factory()->approved()->create([
            'gps_connection_id' => $connection->id,
            'gps_unit_id' => 'unit-1',
        ]);
        $unmatchedTruck = Truck::factory()->approved()->create(['gps_connection_id' => $connection->id, 'gps_unit_id' => null]);

        $this->app->instance(WialonGpsProvider::class, new class implements GpsProvider
        {
            public function listUnits(string $accessToken): array
            {
                return [
                    new GpsUnit('unit-1', 'T 123 ABC', -6.8, 39.2, 90.0, CarbonImmutable::now(), speedKmh: 55.0),
                    new GpsUnit('unit-not-imported', 'T 999 ZZZ', -6.9, 39.3, 0.0, CarbonImmutable::now()),
                    new GpsUnit('unit-no-position', 'T 888 YYY', null, null, null, null),
                ];
            }
        });

        (new PollGpsPositionsJob)->handle($this->app->make(GpsProviderManager::class));

        Bus::assertDispatched(NormalizeGpsPositionJob::class, fn (NormalizeGpsPositionJob $job) => $job->truckId === $truck->id && $job->speedKmh === 55.0);
        // Exactly one: the "not imported" unit has no matching truck, and
        // the "no position" unit is skipped even though a truck exists for
        // it — neither should reach a NormalizeGpsPositionJob.
        Bus::assertDispatchedTimes(NormalizeGpsPositionJob::class, 1);
        $this->assertNotNull($connection->fresh()->last_synced_at);
        $this->assertNull($unmatchedTruck->fresh()->gps_unit_id);
    }

    public function test_a_failing_connection_is_marked_error_without_affecting_others(): void
    {
        Bus::fake();

        $badConnection = GpsConnection::factory()->create(['provider' => 'wialon', 'status' => 'connected']);
        $goodConnection = GpsConnection::factory()->create(['provider' => 'wialon', 'status' => 'connected']);
        $goodTruck = Truck::factory()->approved()->create(['gps_connection_id' => $goodConnection->id, 'gps_unit_id' => 'good-unit']);

        $this->app->instance(WialonGpsProvider::class, new class($badConnection->id, $goodTruck) implements GpsProvider
        {
            public function __construct(private int $badConnectionId, private Truck $goodTruck) {}

            public function listUnits(string $accessToken): array
            {
                if ($accessToken === $this->badToken()) {
                    throw new GpsProviderException('Wialon rejected this API token.');
                }

                return [new GpsUnit('good-unit', 'T 123 ABC', -6.8, 39.2, null, CarbonImmutable::now())];
            }

            private function badToken(): string
            {
                return GpsConnection::find($this->badConnectionId)->access_token;
            }
        });

        (new PollGpsPositionsJob)->handle($this->app->make(GpsProviderManager::class));

        $this->assertSame('error', $badConnection->fresh()->status);
        $this->assertSame('connected', $goodConnection->fresh()->status);
        Bus::assertDispatched(NormalizeGpsPositionJob::class, fn (NormalizeGpsPositionJob $job) => $job->truckId === $goodTruck->id);
    }

    public function test_disconnected_connections_are_never_polled(): void
    {
        Bus::fake();

        GpsConnection::factory()->create(['provider' => 'wialon', 'status' => 'disconnected']);

        $this->app->instance(WialonGpsProvider::class, new class implements GpsProvider
        {
            public function listUnits(string $accessToken): array
            {
                throw new RuntimeException('Should not be called for a disconnected connection.');
            }
        });

        (new PollGpsPositionsJob)->handle($this->app->make(GpsProviderManager::class));

        Bus::assertNotDispatched(NormalizeGpsPositionJob::class);
    }
}
