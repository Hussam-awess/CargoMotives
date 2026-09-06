<?php

namespace Tests\Unit\Broadcasting;

use App\Broadcasting\JobLocationChannel;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * See JobChannelTest's docblock for why this exercises the class directly
 * rather than the /broadcasting/auth route.
 */
class JobLocationChannelTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_jobs_own_customer_can_join(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertTrue((new JobLocationChannel)->join($customer, $job->id));
    }

    public function test_the_assigned_companys_owner_can_join(): void
    {
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->for($companyOwner, 'owner')->create();
        $job = Job::factory()->create(['assigned_company_id' => $company->id]);

        $this->assertTrue((new JobLocationChannel)->join($companyOwner, $job->id));
    }

    public function test_an_unrelated_user_cannot_join(): void
    {
        $companyOwner = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->for($companyOwner, 'owner')->create();
        $job = Job::factory()->create();

        $this->assertFalse((new JobLocationChannel)->join($companyOwner, $job->id));
    }

    public function test_a_different_customer_cannot_join(): void
    {
        $customer = User::factory()->create();
        $otherCustomer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertFalse((new JobLocationChannel)->join($otherCustomer, $job->id));
    }

    public function test_a_nonexistent_job_denies_everyone(): void
    {
        $customer = User::factory()->create();

        $this->assertFalse((new JobLocationChannel)->join($customer, 999999));
    }
}
