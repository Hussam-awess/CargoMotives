<?php

namespace Tests\Feature\Jobs;

use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Cargo Motives Plus benefit: a customer sees how many distinct
 * transporter companies viewed their job (JobView, recorded by
 * CompanyJobController::show()).
 */
class JobViewsTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    public function test_opening_a_job_records_a_view_reflected_on_the_customers_own_job_list(): void
    {
        $customer = User::factory()->create();
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);

        $this->actingAs($company)->getJson("/api/company/jobs/{$job->id}")->assertOk();

        $this->actingAs($customer)
            ->getJson('/api/jobs')
            ->assertOk()
            ->assertJsonPath('data.0.job_views_count', 1);
    }

    public function test_the_same_company_viewing_a_job_repeatedly_only_counts_once(): void
    {
        $customer = User::factory()->create();
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);

        $this->actingAs($company)->getJson("/api/company/jobs/{$job->id}")->assertOk();
        $this->actingAs($company)->getJson("/api/company/jobs/{$job->id}")->assertOk();
        $this->actingAs($company)->getJson("/api/company/jobs/{$job->id}")->assertOk();

        $this->actingAs($customer)
            ->getJson("/api/jobs/{$job->id}")
            ->assertOk()
            ->assertJsonPath('data.job_views_count', 1);
    }

    public function test_two_different_companies_viewing_counts_two(): void
    {
        $customer = User::factory()->create();
        $companyA = $this->approvedCompanyUser();
        $companyB = $this->approvedCompanyUser();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);

        $this->actingAs($companyA)->getJson("/api/company/jobs/{$job->id}")->assertOk();
        $this->actingAs($companyB)->getJson("/api/company/jobs/{$job->id}")->assertOk();

        $this->actingAs($customer)
            ->getJson("/api/jobs/{$job->id}")
            ->assertOk()
            ->assertJsonPath('data.job_views_count', 2);
    }

    public function test_a_job_nobody_has_viewed_yet_shows_zero(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);

        $this->actingAs($customer)
            ->getJson("/api/jobs/{$job->id}")
            ->assertOk()
            ->assertJsonPath('data.job_views_count', 0);
    }
}
