<?php

namespace Tests\Feature\Jobs;

use App\Models\Driver;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class JobAssignmentTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    public function test_a_company_can_assign_an_idle_approved_truck_and_a_driver_to_its_own_job(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create();
        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $response = $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/assign", [
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonStructure(['data' => ['id', 'url', 'status', 'expires_at']]);

        $job->refresh();
        $this->assertSame($truck->id, $job->assigned_truck_id);
        $this->assertSame($driver->id, $job->assigned_driver_id);
        $this->assertSame('on_job', $truck->fresh()->current_status);
        $this->assertDatabaseHas('driver_links', ['job_id' => $job->id, 'driver_id' => $driver->id, 'status' => 'active']);
    }

    public function test_cannot_assign_a_truck_that_belongs_to_another_company(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->assignedTo($company->transporterCompany->id)->create();
        $otherTruck = Truck::factory()->approved()->create();
        $driver = Driver::factory()->create(['transporter_company_id' => $company->transporterCompany->id]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/assign", ['truck_id' => $otherTruck->id, 'driver_id' => $driver->id])
            ->assertUnprocessable();
    }

    public function test_cannot_assign_a_truck_that_is_already_on_another_job(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create();
        $busyTruck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'on_job']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/assign", ['truck_id' => $busyTruck->id, 'driver_id' => $driver->id])
            ->assertUnprocessable();
    }

    public function test_cannot_assign_an_unapproved_truck(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create();
        $pendingTruck = Truck::factory()->create(['transporter_company_id' => $companyId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/assign", ['truck_id' => $pendingTruck->id, 'driver_id' => $driver->id])
            ->assertUnprocessable();
    }

    public function test_a_company_cannot_assign_a_job_it_does_not_own(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $otherJob = Job::factory()->create(['status' => 'open']);
        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$otherJob->id}/assign", ['truck_id' => $truck->id, 'driver_id' => $driver->id])
            ->assertNotFound();
    }

    public function test_reassigning_a_different_truck_frees_the_previous_one(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create();
        $firstTruck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'idle']);
        $secondTruck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/assign", [
            'truck_id' => $firstTruck->id, 'driver_id' => $driver->id,
        ])->assertCreated();

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/assign", [
            'truck_id' => $secondTruck->id, 'driver_id' => $driver->id,
        ])->assertCreated();

        $this->assertSame('idle', $firstTruck->fresh()->current_status);
        $this->assertSame('on_job', $secondTruck->fresh()->current_status);
        $this->assertSame($secondTruck->id, $job->fresh()->assigned_truck_id);
        $this->assertDatabaseHas('driver_links', ['job_id' => $job->id, 'driver_id' => $driver->id, 'status' => 'expired']);
        $this->assertDatabaseHas('driver_links', ['job_id' => $job->id, 'driver_id' => $driver->id, 'status' => 'active']);
    }

    public function test_the_company_can_refetch_the_current_driver_link(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create();
        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/assign", [
            'truck_id' => $truck->id, 'driver_id' => $driver->id,
        ])->assertCreated();

        $this->actingAs($company)
            ->getJson("/api/company/jobs/{$job->id}/driver-link")
            ->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.driver_name', $driver->full_name);
    }

    public function test_refetching_the_driver_link_404s_once_none_is_active(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->assignedTo($company->transporterCompany->id)->create();

        $this->actingAs($company)
            ->getJson("/api/company/jobs/{$job->id}/driver-link")
            ->assertNotFound();
    }
}
