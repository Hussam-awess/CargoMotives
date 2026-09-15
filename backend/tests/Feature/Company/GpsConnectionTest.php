<?php

namespace Tests\Feature\Company;

use App\Models\GpsConnection;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use App\Services\Gps\GpsProvider;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsUnit;
use App\Services\Gps\Traccar\TraccarGpsProvider;
use App\Services\Gps\Tracksolid\TracksolidGpsProvider;
use App\Services\Gps\Wialon\WialonGpsProvider;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Connect GPS (AppFlow §2.3). Uses a fake GpsProvider bound in the
 * container (at WialonGpsProvider::class, the concrete class
 * GpsProviderManager::driver('wialon') resolves — see that class's own
 * docblock for why binding stays per-concrete-class rather than at the
 * shared GpsProvider interface) rather than Http::fake against the real
 * Wialon endpoint — this is the same reasoning as PollGpsPositionsJobTest:
 * this controller's own authorization/persistence logic is what's under
 * test, and WialonGpsProviderTest already covers the real HTTP shape.
 */
class GpsConnectionTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    private function fakeUnits(array $units): void
    {
        $this->app->instance(WialonGpsProvider::class, new class($units) implements GpsProvider
        {
            public function __construct(private array $units) {}

            public function listUnits(string $accessToken): array
            {
                return $this->units;
            }
        });
    }

    public function test_connecting_authorizes_and_returns_units_with_a_suggested_match(): void
    {
        $company = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->create([
            'transporter_company_id' => $company->transporterCompany->id,
            'registration_number' => 'T 123 ABC',
        ]);
        $this->fakeUnits([
            new GpsUnit('unit-1', 'T123ABC', -6.8, 39.2, 90.0, CarbonImmutable::now()),
            new GpsUnit('unit-2', 'Some Other Truck', null, null, null, null),
        ]);

        $response = $this->actingAs($company)->postJson('/api/company/gps-connections', [
            'provider' => 'wialon',
            'access_token' => 'a-real-token',
        ]);

        $response->assertOk()
            ->assertJsonPath('connection.provider', 'wialon')
            ->assertJsonPath('connection.status', 'connected')
            ->assertJsonPath('units.0.unit_id', 'unit-1')
            ->assertJsonPath('units.0.suggested_truck_id', $truck->id)
            ->assertJsonPath('units.1.suggested_truck_id', null);

        $this->assertDatabaseHas('gps_connections', [
            'transporter_company_id' => $company->transporterCompany->id,
            'provider' => 'wialon',
            'status' => 'connected',
        ]);
    }

    public function test_an_invalid_token_surfaces_as_a_validation_error_and_creates_no_connection(): void
    {
        $company = $this->approvedCompanyUser();
        $this->app->instance(WialonGpsProvider::class, new class implements GpsProvider
        {
            public function listUnits(string $accessToken): array
            {
                throw new GpsProviderException('Wialon rejected this API token.');
            }
        });

        $this->actingAs($company)
            ->postJson('/api/company/gps-connections', ['provider' => 'wialon', 'access_token' => 'bad-token'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('access_token');

        $this->assertDatabaseCount('gps_connections', 0);
    }

    public function test_an_unsupported_provider_is_rejected(): void
    {
        $company = $this->approvedCompanyUser();

        $this->actingAs($company)
            ->postJson('/api/company/gps-connections', ['provider' => 'samsara', 'access_token' => 'x'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('provider');
    }

    public function test_traccar_is_a_supported_provider(): void
    {
        $company = $this->approvedCompanyUser();
        $this->app->instance(TraccarGpsProvider::class, new class implements GpsProvider
        {
            public function listUnits(string $accessToken): array
            {
                return [new GpsUnit('unit-1', 'T 123 ABC', -6.8, 39.2, 90.0, CarbonImmutable::now())];
            }
        });

        $this->actingAs($company)->postJson('/api/company/gps-connections', [
            'provider' => 'traccar',
            'access_token' => 'a-real-token',
        ])->assertOk()->assertJsonPath('connection.provider', 'traccar');
    }

    public function test_tracksolid_is_a_supported_provider(): void
    {
        $company = $this->approvedCompanyUser();
        $this->app->instance(TracksolidGpsProvider::class, new class implements GpsProvider
        {
            public function listUnits(string $accessToken): array
            {
                return [new GpsUnit('unit-1', 'T 123 ABC', -6.8, 39.2, 90.0, CarbonImmutable::now())];
            }
        });

        $this->actingAs($company)->postJson('/api/company/gps-connections', [
            'provider' => 'tracksolid_pro',
            'access_token' => 'a-real-token',
        ])->assertOk()->assertJsonPath('connection.provider', 'tracksolid_pro');
    }

    public function test_reconnecting_the_same_provider_updates_the_existing_connection(): void
    {
        $company = $this->approvedCompanyUser();
        $this->fakeUnits([]);

        $this->actingAs($company)->postJson('/api/company/gps-connections', [
            'provider' => 'wialon', 'access_token' => 'first-token',
        ])->assertOk();

        $this->actingAs($company)->postJson('/api/company/gps-connections', [
            'provider' => 'wialon', 'access_token' => 'second-token',
        ])->assertOk();

        $this->assertDatabaseCount('gps_connections', 1);
    }

    public function test_importing_links_confirmed_units_to_trucks(): void
    {
        $company = $this->approvedCompanyUser();
        $connection = GpsConnection::factory()->create(['transporter_company_id' => $company->transporterCompany->id]);
        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $company->transporterCompany->id]);

        $response = $this->actingAs($company)->postJson("/api/company/gps-connections/{$connection->id}/import", [
            'matches' => [['unit_id' => 'unit-1', 'truck_id' => $truck->id]],
        ]);

        $response->assertOk()->assertJsonPath('data.0.gps_status', 'connected');

        $truck->refresh();
        $this->assertSame('connected', $truck->gps_status);
        $this->assertSame($connection->id, $truck->gps_connection_id);
        $this->assertSame('unit-1', $truck->gps_unit_id);
    }

    public function test_cannot_import_a_truck_belonging_to_another_company(): void
    {
        $company = $this->approvedCompanyUser();
        $connection = GpsConnection::factory()->create(['transporter_company_id' => $company->transporterCompany->id]);
        $otherTruck = Truck::factory()->approved()->create();

        $this->actingAs($company)
            ->postJson("/api/company/gps-connections/{$connection->id}/import", [
                'matches' => [['unit_id' => 'unit-1', 'truck_id' => $otherTruck->id]],
            ])
            ->assertUnprocessable();

        $this->assertSame('not_connected', $otherTruck->fresh()->gps_status);
    }

    public function test_cannot_import_into_another_companys_connection(): void
    {
        $company = $this->approvedCompanyUser();
        $otherConnection = GpsConnection::factory()->create();
        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $company->transporterCompany->id]);

        $this->actingAs($company)
            ->postJson("/api/company/gps-connections/{$otherConnection->id}/import", [
                'matches' => [['unit_id' => 'unit-1', 'truck_id' => $truck->id]],
            ])
            ->assertNotFound();
    }

    public function test_lists_the_companys_own_connections(): void
    {
        $company = $this->approvedCompanyUser();
        GpsConnection::factory()->create(['transporter_company_id' => $company->transporterCompany->id]);
        GpsConnection::factory()->create(); // another company's — must not appear

        $this->actingAs($company)
            ->getJson('/api/company/gps-connections')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }
}
