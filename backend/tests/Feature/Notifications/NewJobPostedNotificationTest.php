<?php

namespace Tests\Feature\Notifications;

use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class NewJobPostedNotificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_every_approved_company_is_notified_when_a_job_is_posted(): void
    {
        Queue::fake();

        $approvedOne = TransporterCompany::factory()->approved()->create();
        $approvedTwo = TransporterCompany::factory()->approved()->create();
        $pending = TransporterCompany::factory()->create();

        $job = Job::factory()->create();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $approvedOne->owner_user_id,
            'type' => 'new_job_posted',
            'related_job_id' => $job->id,
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $approvedTwo->owner_user_id,
            'type' => 'new_job_posted',
            'related_job_id' => $job->id,
        ]);
        $this->assertDatabaseMissing('notifications', [
            'user_id' => $pending->owner_user_id,
            'type' => 'new_job_posted',
        ]);
    }

    public function test_a_company_that_disabled_new_job_matches_is_not_notified(): void
    {
        Queue::fake();

        $company = TransporterCompany::factory()->approved()->create();
        User::where('id', $company->owner_user_id)->update([
            'notification_preferences' => ['new_job_matches' => false],
        ]);

        Job::factory()->create();

        $this->assertDatabaseMissing('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'new_job_posted',
        ]);
    }
}
