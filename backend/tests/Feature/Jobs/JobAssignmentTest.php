<?php

namespace Tests\Feature\Jobs;

use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
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
        // No GPS on this truck (Phase 6) — the job must never claim to be
        // trackable just because it now has a truck assigned.
        $this->assertFalse((bool) $job->gps_tracking_active);
        $this->assertSame('not_applicable', $job->gps_signal_status);
    }

    public function test_assigning_a_gps_connected_truck_marks_the_job_trackable(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create();
        $truck = Truck::factory()->approved()->create([
            'transporter_company_id' => $companyId,
            'current_status' => 'idle',
            'gps_status' => 'connected',
        ]);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/assign", [
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
        ])->assertCreated();

        $job->refresh();
        $this->assertTrue((bool) $job->gps_tracking_active);
        $this->assertSame('ok', $job->gps_signal_status);
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

    /**
     * A truck/driver can only be swapped before the job has actually
     * started — once the driver has advanced past 'assigned' (the
     * shipment is genuinely underway), the truck already moving can't be
     * pulled out from under it.
     */
    public function test_reassigning_a_truck_once_the_job_has_started_is_rejected(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->create(['assigned_company_id' => $companyId, 'status' => 'en_route_pickup']);
        $firstTruck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'on_job']);
        $secondTruck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/assign", ['truck_id' => $secondTruck->id, 'driver_id' => $driver->id])
            ->assertUnprocessable();

        $this->assertSame('idle', $secondTruck->fresh()->current_status);
        $this->assertSame('on_job', $firstTruck->fresh()->current_status);
    }

    /**
     * A multi-truck job's roster is built up incrementally (Bulk Cargo
     * epic) — adding a new truck must stay allowed even once the lead
     * truck is already en route, unlike the single-truck swap case above.
     */
    public function test_adding_a_truck_to_a_multi_truck_jobs_roster_is_still_allowed_once_the_lead_is_en_route(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->create([
            'assigned_company_id' => $companyId,
            'status' => 'en_route_pickup',
            'trucks_needed' => 2,
        ]);
        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);

        $this->actingAs($company)
            ->postJson("/api/company/jobs/{$job->id}/assign", ['truck_id' => $truck->id, 'driver_id' => $driver->id])
            ->assertCreated();

        $this->assertDatabaseHas('job_truck_assignments', ['job_id' => $job->id, 'truck_id' => $truck->id]);
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

    /**
     * The manual escape hatch for a stuck 'in_transit' job (a real,
     * live-reported bug: an inaccurate pickup location meant the truck
     * never crossed JobStatusAutoAdvancer's departure/arrival radii) — the
     * company can submit proof of delivery itself, from its own app,
     * instead of needing the driver to visit the separate Driver Link page.
     */
    public function test_a_company_can_submit_proof_of_delivery_for_its_own_stuck_job(): void
    {
        Storage::fake('local');
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create(['status' => 'in_transit', 'dropoff_permit_path' => 'permits/test.pdf']);
        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $companyId, 'current_status' => 'on_job']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);
        $job->update(['assigned_truck_id' => $truck->id, 'assigned_driver_id' => $driver->id]);
        $link = DriverLink::create([
            'job_id' => $job->id, 'driver_id' => $driver->id, 'token' => 'test-token-1',
            'status' => 'active', 'expires_at' => now()->addDays(2),
        ]);

        $response = $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
            'recipient_name' => 'Asha Mwinyi',
        ]);

        $response->assertOk()->assertJsonPath('data.status', 'delivered');
        $this->assertSame('delivered', $job->fresh()->status);
        $this->assertDatabaseHas('proof_of_deliveries', [
            'job_id' => $job->id, 'driver_id' => $driver->id, 'driver_link_id' => $link->id, 'recipient_name' => 'Asha Mwinyi',
        ]);
        $this->assertSame('used', $link->fresh()->status);
    }

    public function test_cannot_submit_proof_of_delivery_for_a_job_already_delivered(): void
    {
        Storage::fake('local');
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create(['status' => 'delivered']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);
        DriverLink::create([
            'job_id' => $job->id, 'driver_id' => $driver->id, 'token' => 'test-token-2',
            'status' => 'used', 'expires_at' => now()->addDays(2), 'used_at' => now(),
        ]);

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
        ])->assertUnprocessable()->assertJsonValidationErrors(['status']);
    }

    public function test_cannot_submit_proof_of_delivery_for_a_job_it_does_not_own(): void
    {
        Storage::fake('local');
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->create(['status' => 'in_transit']); // owned by a different (or no) company

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
        ])->assertNotFound();
    }

    public function test_submitting_proof_of_delivery_requires_at_least_one_photo(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->assignedTo($company->transporterCompany->id)->create(['status' => 'in_transit']);

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/proof-of-delivery", [])
            ->assertUnprocessable()->assertJsonValidationErrors(['photos']);
    }

    public function test_cannot_submit_proof_of_delivery_without_a_dropoff_permit_attached(): void
    {
        Storage::fake('local');
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->assignedTo($company->transporterCompany->id)->create(['status' => 'in_transit']); // no dropoff_permit_path

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
        ])->assertUnprocessable()->assertJsonValidationErrors(['dropoff_permit']);
        $this->assertSame('in_transit', $job->fresh()->status);
    }
}
