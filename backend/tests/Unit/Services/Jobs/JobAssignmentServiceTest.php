<?php

namespace Tests\Unit\Services\Jobs;

use App\Models\Driver;
use App\Models\Job;
use App\Models\JobTruckAssignment;
use App\Models\Truck;
use App\Services\Jobs\JobAssignmentService;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

/**
 * Confirms the TRD §5.3 graceful-degradation guarantee for the Driver
 * Link's SMS delivery: "a Driver Link can be viewed/shared manually from
 * the company's app if the SMS fails to send" — an SMS failure must never
 * prevent the assignment itself, or the caller would have no link to
 * share manually in the first place.
 */
class JobAssignmentServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_assignment_succeeds_even_when_the_sms_gateway_fails(): void
    {
        $this->app->instance(SmsGateway::class, new class implements SmsGateway
        {
            public function send(string $to, string $body): SmsSendResult
            {
                return SmsSendResult::failure('provider outage');
            }
        });

        $job = Job::factory()->assigned()->create();
        $truck = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver = Driver::factory()->create();

        $link = $this->app->make(JobAssignmentService::class)->assign($job, $truck, $driver);

        $this->assertTrue($link->exists);
        $this->assertSame('active', $link->status);
        $this->assertNotEmpty($link->url());
        $this->assertSame($truck->id, $job->fresh()->assigned_truck_id);
    }

    public function test_adding_a_second_truck_to_a_multi_truck_job_does_not_expire_the_first_trucks_link(): void
    {
        $job = Job::factory()->assigned()->create(['trucks_needed' => 20]);
        $truck1 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver1 = Driver::factory()->create();
        $truck2 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver2 = Driver::factory()->create();

        $service = $this->app->make(JobAssignmentService::class);
        $link1 = $service->assign($job, $truck1, $driver1);
        $link2 = $service->assign($job->fresh(), $truck2, $driver2);

        $this->assertSame('active', $link1->fresh()->status);
        $this->assertSame('active', $link2->fresh()->status);
        $this->assertNotSame($link1->id, $link2->id);
    }

    public function test_only_the_first_truck_added_becomes_the_jobs_lead_and_assigned_truck(): void
    {
        $job = Job::factory()->assigned()->create(['trucks_needed' => 20]);
        $truck1 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver1 = Driver::factory()->create();
        $truck2 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver2 = Driver::factory()->create();

        $service = $this->app->make(JobAssignmentService::class);
        $service->assign($job, $truck1, $driver1);
        $service->assign($job->fresh(), $truck2, $driver2);

        $fresh = $job->fresh();
        $this->assertSame($truck1->id, $fresh->assigned_truck_id);
        $this->assertSame($driver1->id, $fresh->assigned_driver_id);

        $this->assertTrue(JobTruckAssignment::where(['job_id' => $job->id, 'truck_id' => $truck1->id])->value('is_lead'));
        $this->assertFalse(JobTruckAssignment::where(['job_id' => $job->id, 'truck_id' => $truck2->id])->value('is_lead'));
        $this->assertSame(2, JobTruckAssignment::where('job_id', $job->id)->count());
    }

    public function test_rejects_assigning_a_truck_once_the_multi_truck_roster_is_full(): void
    {
        // Smallest possible multi-truck job (trucks_needed must be > 1 to
        // take the roster path at all) — fill both slots, then a third
        // attempt must be rejected as over capacity.
        $job = Job::factory()->assigned()->create(['trucks_needed' => 2]);
        $truck1 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver1 = Driver::factory()->create();
        $truck2 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver2 = Driver::factory()->create();
        $truck3 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver3 = Driver::factory()->create();

        $service = $this->app->make(JobAssignmentService::class);
        $service->assign($job, $truck1, $driver1);
        $service->assign($job->fresh(), $truck2, $driver2);

        $this->expectException(ValidationException::class);
        $service->assign($job->fresh(), $truck3, $driver3);
    }

    public function test_rejects_adding_the_same_truck_twice_to_a_multi_truck_jobs_roster(): void
    {
        $job = Job::factory()->assigned()->create(['trucks_needed' => 20]);
        $truck = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver1 = Driver::factory()->create();
        $driver2 = Driver::factory()->create();

        $service = $this->app->make(JobAssignmentService::class);
        $service->assign($job, $truck, $driver1);
        // Simulate the truck having been freed up again elsewhere — this
        // isolates the "already on this job's roster" rejection from the
        // separate "truck not idle" one, which would otherwise also fire.
        $truck->update(['current_status' => 'idle']);

        $this->expectException(ValidationException::class);
        $service->assign($job->fresh(), $truck->fresh(), $driver2);
    }

    public function test_an_ordinary_single_truck_job_still_swaps_trucks_exactly_as_before(): void
    {
        $job = Job::factory()->assigned()->create(['trucks_needed' => 1]);
        $truck1 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver1 = Driver::factory()->create();
        $truck2 = Truck::factory()->approved()->create(['current_status' => 'idle']);
        $driver2 = Driver::factory()->create();

        $service = $this->app->make(JobAssignmentService::class);
        $link1 = $service->assign($job, $truck1, $driver1);
        $service->assign($job->fresh(), $truck2, $driver2);

        $this->assertSame('idle', $truck1->fresh()->current_status);
        $this->assertSame('expired', $link1->fresh()->status);
        $this->assertSame($truck2->id, $job->fresh()->assigned_truck_id);
        $this->assertSame(0, JobTruckAssignment::where('job_id', $job->id)->count());
    }
}
