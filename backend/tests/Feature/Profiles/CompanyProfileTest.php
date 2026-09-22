<?php

namespace Tests\Feature\Profiles;

use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CompanyProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_shows_the_companys_public_profile(): void
    {
        $viewer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create([
            'company_name' => 'ABC Logistics',
            'physical_address' => 'Nyerere Road, Dar es Salaam',
        ]);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}");

        $response->assertOk()
            ->assertJsonPath('data.id', $company->id)
            ->assertJsonPath('data.company_name', 'ABC Logistics')
            ->assertJsonPath('data.verified', true)
            ->assertJsonPath('data.location', 'Nyerere Road, Dar es Salaam')
            ->assertJsonPath('data.rating_count', 0)
            ->assertJsonPath('data.completed_jobs_count', 0);
    }

    public function test_shows_the_companys_own_logo_when_it_has_one(): void
    {
        $viewer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create(['logo_url' => 'companies/logos/fake-logo.jpg']);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}");

        $response->assertOk();
        $this->assertNotNull($response->json('data.logo_url'));
    }

    /**
     * A company logo is optional at verification time — most companies
     * never bother. Falling all the way back to an initial-letter avatar
     * when the owner DID upload a personal photo would hide a real
     * picture a customer could otherwise see.
     */
    public function test_falls_back_to_the_owners_personal_avatar_when_the_company_has_no_logo(): void
    {
        $owner = User::factory()->transporterCompany()->create(['avatar_url' => 'users/avatars/fake-avatar.jpg']);
        $company = TransporterCompany::factory()->approved()->for($owner, 'owner')->create(['logo_url' => null]);
        $viewer = User::factory()->create();

        $response = $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}");

        $response->assertOk()->assertJsonPath('data.logo_url', null);
        $this->assertNotNull($response->json('data.owner_avatar_url'));
    }

    public function test_owner_avatar_is_null_when_neither_a_logo_nor_a_personal_avatar_exists(): void
    {
        $owner = User::factory()->transporterCompany()->create(['avatar_url' => null]);
        $company = TransporterCompany::factory()->approved()->for($owner, 'owner')->create(['logo_url' => null]);
        $viewer = User::factory()->create();

        $response = $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}");

        $response->assertOk()->assertJsonPath('data.owner_avatar_url', null);
    }

    public function test_a_pending_companys_profile_shows_verified_false(): void
    {
        $viewer = User::factory()->create();
        $company = TransporterCompany::factory()->create();

        $this->actingAs($viewer)
            ->getJson("/api/profiles/companies/{$company->id}")
            ->assertOk()
            ->assertJsonPath('data.verified', false);
    }

    public function test_never_exposes_registration_or_representative_details(): void
    {
        $viewer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();

        $response = $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}");

        $data = $response->json('data');
        foreach (['registration_number', 'tin', 'company_phone', 'company_email', 'rep_full_name', 'rep_national_id_number', 'documents', 'is_following'] as $key) {
            $this->assertArrayNotHasKey($key, $data);
        }
    }

    public function test_completed_jobs_count_is_accurate_and_has_no_cancelled_count(): void
    {
        $viewer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        Job::factory()->count(3)->create(['assigned_company_id' => $company->id, 'status' => 'completed']);
        Job::factory()->create(['assigned_company_id' => $company->id, 'status' => 'in_transit']);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}");

        $response->assertOk()->assertJsonPath('data.completed_jobs_count', 3);
        // No real "transporter cancelled" action exists in this app — see
        // CompanyProfileResource's docblock for why this is omitted rather
        // than shown as an always-zero, misleading stat.
        $this->assertArrayNotHasKey('cancelled_jobs_count', $response->json('data'));
    }

    public function test_fleet_size_counts_only_approved_trucks(): void
    {
        $viewer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        Truck::factory()->approved()->count(2)->create(['transporter_company_id' => $company->id]);
        Truck::factory()->create(['transporter_company_id' => $company->id, 'verification_status' => 'pending']);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}");

        $response->assertOk()->assertJsonPath('data.fleet_size', 2);
    }

    public function test_recent_completed_jobs_never_reveal_the_customer(): void
    {
        $viewer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        Job::factory()->create([
            'assigned_company_id' => $company->id,
            'status' => 'completed',
            'completed_at' => now(),
            'pickup_address' => 'Kariakoo, Dar es Salaam',
            'dropoff_address' => 'Mbezi Beach, Dar es Salaam',
        ]);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}");

        $recent = $response->json('data.recent_completed_jobs')[0];
        $this->assertSame('Kariakoo → Mbezi Beach', $recent['route']);
        $this->assertArrayNotHasKey('customer_name', $recent);
        $this->assertArrayNotHasKey('id', $recent);
    }

    public function test_the_full_reviews_list_is_reachable(): void
    {
        $viewer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();

        $this->actingAs($viewer)
            ->getJson("/api/profiles/companies/{$company->id}/reviews")
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_shows_the_companys_plus_badge_status(): void
    {
        $viewer = User::factory()->create();
        $plusCompany = TransporterCompany::factory()->approved()->create(['is_featured' => true]);
        $standardCompany = TransporterCompany::factory()->approved()->create(['is_featured' => false]);

        $this->actingAs($viewer)
            ->getJson("/api/profiles/companies/{$plusCompany->id}")
            ->assertOk()
            ->assertJsonPath('data.is_featured', true);

        $this->actingAs($viewer)
            ->getJson("/api/profiles/companies/{$standardCompany->id}")
            ->assertOk()
            ->assertJsonPath('data.is_featured', false);
    }
}
