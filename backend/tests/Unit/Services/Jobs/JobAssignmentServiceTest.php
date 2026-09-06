<?php

namespace Tests\Unit\Services\Jobs;

use App\Models\Driver;
use App\Models\Job;
use App\Models\Truck;
use App\Services\Jobs\JobAssignmentService;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
}
