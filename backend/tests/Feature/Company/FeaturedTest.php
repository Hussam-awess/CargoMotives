<?php

namespace Tests\Feature\Company;

use App\Models\Job;
use App\Models\PlatformSetting;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use App\Services\Geo\GeoPoint;
use App\Services\MobileMoney\MobileMoneyChargeResult;
use App\Services\MobileMoney\MobileMoneyGateway;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FeaturedTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(array $companyAttributes = []): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create($companyAttributes);

        return $user;
    }

    public function test_status_reports_price_and_current_state(): void
    {
        PlatformSetting::create(['key' => 'company_featured_price', 'value' => '50000']);
        $company = $this->approvedCompanyUser(['is_featured' => false]);

        $this->actingAs($company)
            ->getJson('/api/company/featured/status')
            ->assertOk()
            ->assertJson(['is_featured' => false, 'price' => 50000.0]);
    }

    public function test_purchasing_pushes_a_charge_but_does_not_activate_immediately(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => false]);

        $this->mock(MobileMoneyGateway::class, function ($mock) {
            $mock->shouldReceive('initiateCharge')->once()->andReturn(MobileMoneyChargeResult::initiated('ref-1'));
        });

        $this->actingAs($company)
            ->postJson('/api/company/featured/purchase', ['mobile_money_provider' => 'mpesa', 'phone_number' => '0712345678'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending_confirmation');

        $this->assertFalse((bool) $company->transporterCompany->fresh()->is_featured);
        $this->assertDatabaseHas('payments', ['purpose' => 'featured_company', 'status' => 'pending_confirmation']);
    }

    public function test_a_non_featured_company_cannot_set_preferred_routes(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => false]);

        $this->actingAs($company)
            ->postJson('/api/company/featured/preferred-routes', ['routes' => [['origin' => 'Dar', 'destination' => 'Arusha']]])
            ->assertForbidden();
    }

    public function test_a_featured_company_can_set_preferred_routes(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => true]);

        $this->actingAs($company)
            ->postJson('/api/company/featured/preferred-routes', ['routes' => [['origin' => 'Dar', 'destination' => 'Arusha']]])
            ->assertOk()
            ->assertJson(['preferred_routes' => [['origin' => 'Dar', 'destination' => 'Arusha']]]);
    }

    /**
     * home_region (return-load matching) lives on the same settings screen
     * and the same save call as preferred routes.
     */
    public function test_a_featured_company_can_set_its_home_region(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => true]);

        $this->actingAs($company)
            ->postJson('/api/company/featured/preferred-routes', ['routes' => [], 'home_region' => 'Mwanza'])
            ->assertOk()
            ->assertJson(['home_region' => 'Mwanza']);

        $this->actingAs($company)
            ->getJson('/api/company/featured/status')
            ->assertOk()
            ->assertJson(['home_region' => 'Mwanza']);
    }

    public function test_the_open_jobs_feed_filters_to_preferred_routes_when_requested(): void
    {
        $company = $this->approvedCompanyUser([
            'is_featured' => true,
            'preferred_routes' => [['origin' => 'Kariakoo', 'destination' => 'Mbezi']],
        ]);
        $matching = Job::factory()->create(['status' => 'open', 'pickup_address' => 'Kariakoo Market, Dar', 'dropoff_address' => 'Mbezi Beach, Dar']);
        $nonMatching = Job::factory()->create(['status' => 'open', 'pickup_address' => 'Ubungo, Dar', 'dropoff_address' => 'Tegeta, Dar']);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open?use_preferred_routes=1');

        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($matching->id));
        $this->assertFalse($ids->contains($nonMatching->id));
    }

    public function test_the_preferred_routes_filter_is_ignored_for_a_non_featured_company(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => false]);
        // Backdated past the "early visibility" window (Phase 10.19) —
        // this test is about the preferred-routes filter, not that gate.
        $job = Job::factory()->create(['status' => 'open', 'created_at' => now()->subMinutes(5)]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open?use_preferred_routes=1');

        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($job->id));
    }

    public function test_the_fleet_map_returns_only_gps_connected_trucks(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => true]);
        $companyId = $company->transporterCompany->id;
        $connected = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'gps_status' => 'connected']);
        Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'gps_status' => 'not_connected']);

        $response = $this->actingAs($company)->getJson('/api/company/fleet/map');

        $ids = collect($response->json('data'))->pluck('id');
        $this->assertEquals([$connected->id], $ids->all());
    }

    public function test_the_fleet_map_is_available_to_a_non_featured_company_too(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => false]);
        $companyId = $company->transporterCompany->id;
        $connected = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'gps_status' => 'connected']);

        $response = $this->actingAs($company)->getJson('/api/company/fleet/map');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertEquals([$connected->id], $ids->all());
    }

    public function test_return_load_suggestions_finds_nearby_open_jobs(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => true]);
        $companyId = $company->transporterCompany->id;

        // Completed job dropping off around (-6.79, 39.21) — a real
        // Dar es Salaam-area point (matches JobFactory's own jittering).
        $completedJob = Job::factory()->create(['assigned_company_id' => $companyId, 'status' => 'completed']);
        $completedJob->setDropoffLocation(new GeoPoint(-6.79, 39.21));
        $completedJob->save();

        $nearbyOpenJob = Job::factory()->create(['status' => 'open']);
        $nearbyOpenJob->setPickupLocation(new GeoPoint(-6.791, 39.211));
        $nearbyOpenJob->save();

        $farOpenJob = Job::factory()->create(['status' => 'open']);
        $farOpenJob->setPickupLocation(new GeoPoint(-1.0, 35.0));
        $farOpenJob->save();

        $response = $this->actingAs($company)->getJson("/api/company/jobs/{$completedJob->id}/return-load-suggestions");

        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($nearbyOpenJob->id));
        $this->assertFalse($ids->contains($farOpenJob->id));
    }

    public function test_return_load_suggestions_forbidden_for_a_non_featured_company(): void
    {
        $company = $this->approvedCompanyUser(['is_featured' => false]);
        $job = Job::factory()->create(['assigned_company_id' => $company->transporterCompany->id, 'status' => 'completed']);

        $this->actingAs($company)->getJson("/api/company/jobs/{$job->id}/return-load-suggestions")->assertForbidden();
    }
}
