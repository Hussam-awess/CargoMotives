<?php

namespace Tests\Feature\Company;

use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CompanyPreferencesTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(array $companyAttributes = []): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create($companyAttributes);

        return $user;
    }

    public function test_a_company_can_set_auto_decline_and_a_floor_rate(): void
    {
        $company = $this->approvedCompanyUser();

        $response = $this->actingAs($company)->postJson('/api/company/preferences', [
            'auto_decline_below_budget' => true,
            'floor_rate' => 500000,
        ]);

        $response->assertOk()
            ->assertJsonPath('data.auto_decline_below_budget', true)
            ->assertJsonPath('data.floor_rate', 500000)
            ->assertJsonPath('data.floor_rate_currency', 'TZS');
    }

    public function test_the_floor_rate_currency_follows_the_display_currency_set_in_the_same_request(): void
    {
        $company = $this->approvedCompanyUser();

        $response = $this->actingAs($company)->postJson('/api/company/preferences', [
            'display_currency' => 'USD',
            'floor_rate' => 200,
        ]);

        $response->assertOk()
            ->assertJsonPath('data.display_currency', 'USD')
            ->assertJsonPath('data.floor_rate_currency', 'USD');
    }

    public function test_display_currency_only_accepts_known_currencies(): void
    {
        $company = $this->approvedCompanyUser();

        $this->actingAs($company)->postJson('/api/company/preferences', ['display_currency' => 'EUR'])
            ->assertUnprocessable()->assertJsonValidationErrors(['display_currency']);
    }

    public function test_a_verified_truck_is_required_for_the_open_jobs_feed_but_floor_rate_filtering_is_independent(): void
    {
        // is_featured: true bypasses the unrelated "early visibility" gate
        // (CompanyJobController::open() hides jobs newer than 2 minutes
        // from non-Featured companies) — this test is about floor-rate
        // filtering only.
        $company = $this->approvedCompanyUser([
            'auto_decline_below_budget' => true, 'floor_rate' => 500000, 'floor_rate_currency' => 'TZS', 'is_featured' => true,
        ]);
        Truck::factory()->approved()->create(['transporter_company_id' => $company->transporterCompany->id]);

        $belowFloor = Job::factory()->create(['status' => 'open', 'currency' => 'TZS', 'budget_price' => 300000]);
        $aboveFloor = Job::factory()->create(['status' => 'open', 'currency' => 'TZS', 'budget_price' => 700000]);
        $crossCurrency = Job::factory()->create(['status' => 'open', 'currency' => 'USD', 'budget_price' => 100]);
        $noBudget = Job::factory()->create(['status' => 'open', 'currency' => 'TZS', 'budget_price' => null]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $ids = collect($response->json('data'))->pluck('id');
        $response->assertOk();
        $this->assertFalse($ids->contains($belowFloor->id), 'below-floor job should be hidden');
        $this->assertTrue($ids->contains($aboveFloor->id), 'above-floor job should stay visible');
        $this->assertTrue($ids->contains($crossCurrency->id), 'cross-currency job should never be hidden');
        $this->assertTrue($ids->contains($noBudget->id), 'a job with no stated budget should never be hidden');
    }

    public function test_a_below_floor_job_stays_visible_when_auto_decline_is_off(): void
    {
        $company = $this->approvedCompanyUser(['auto_decline_below_budget' => false, 'floor_rate' => 500000, 'is_featured' => true]);
        Truck::factory()->approved()->create(['transporter_company_id' => $company->transporterCompany->id]);
        $belowFloor = Job::factory()->create(['status' => 'open', 'currency' => 'TZS', 'budget_price' => 300000]);

        $response = $this->actingAs($company)->getJson('/api/company/jobs/open');

        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($belowFloor->id));
    }
}
