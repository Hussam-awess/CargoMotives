<?php

namespace Tests\Feature\Jobs;

use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsSendResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class DriverInstructionsTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    public function test_a_company_can_set_instructions_which_text_the_active_driver(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create();
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId, 'phone_number' => '0712345678']);
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id, 'status' => 'active']);

        $sms = Mockery::mock(SmsGateway::class);
        $sms->shouldReceive('send')
            ->once()
            ->with('0712345678', Mockery::pattern("/Job #{$job->id}.*Please call ahead/"))
            ->andReturn(SmsSendResult::success());
        $this->app->instance(SmsGateway::class, $sms);

        $response = $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/instructions", [
            'instructions' => 'Please call ahead before arriving at the gate.',
        ]);

        $response->assertOk()->assertJsonPath('data.driver_instructions', 'Please call ahead before arriving at the gate.');
        $this->assertSame('Please call ahead before arriving at the gate.', $job->fresh()->driver_instructions);
        $this->assertSame('active', $link->fresh()->status);
    }

    public function test_does_not_sms_an_inactive_driver_link(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        $job = Job::factory()->assignedTo($companyId)->create();
        $driver = Driver::factory()->create(['transporter_company_id' => $companyId]);
        DriverLink::factory()->used()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);

        $sms = Mockery::mock(SmsGateway::class);
        $sms->shouldNotReceive('send');
        $this->app->instance(SmsGateway::class, $sms);

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/instructions", [
            'instructions' => 'Updated pickup gate.',
        ])->assertOk();
    }

    public function test_requires_a_non_empty_instructions_string(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->assignedTo($company->transporterCompany->id)->create();

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/instructions", [])
            ->assertUnprocessable()->assertJsonValidationErrors(['instructions']);
    }

    public function test_a_company_cannot_set_instructions_on_a_job_it_does_not_own(): void
    {
        $company = $this->approvedCompanyUser();
        $job = Job::factory()->assigned()->create(); // owned by a different company

        $this->actingAs($company)->postJson("/api/company/jobs/{$job->id}/instructions", [
            'instructions' => 'Trying to sneak in.',
        ])->assertNotFound();
    }
}
