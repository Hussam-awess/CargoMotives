<?php

namespace Tests\Feature\Notifications;

use App\Models\CustomerFollow;
use App\Models\Job;
use App\Models\Notification;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

/**
 * Phase: Follow system — a company is notified of a new job only when it
 * follows that job's customer, replacing the old "every approved company"
 * broadcast (see JobObserver::created()'s docblock for why).
 */
class NewJobPostedNotificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_following_approved_company_is_notified_when_the_followed_customer_posts_a_job(): void
    {
        Queue::fake();

        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        Truck::factory()->approved()->for($company, 'company')->create();
        CustomerFollow::create(['transporter_company_id' => $company->id, 'customer_id' => $customer->id]);

        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'new_job_posted',
            'related_job_id' => $job->id,
        ]);
    }

    public function test_a_company_that_does_not_follow_the_customer_is_not_notified(): void
    {
        Queue::fake();

        $customer = User::factory()->create();
        TransporterCompany::factory()->approved()->create();

        Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertDatabaseMissing('notifications', ['type' => 'new_job_posted']);
    }

    /**
     * Multi-Company Split Awards epic: a small fleet can now legitimately
     * bid on part of a big job, so it's no longer skipped just for being
     * smaller than trucks_needed — only a company with zero verified
     * trucks (structurally unable to bid on anything) is skipped, per the
     * test below.
     */
    public function test_a_following_company_with_a_small_fleet_is_still_notified_of_a_larger_bulk_job(): void
    {
        Queue::fake();

        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        Truck::factory()->approved()->for($company, 'company')->create();
        CustomerFollow::create(['transporter_company_id' => $company->id, 'customer_id' => $customer->id]);

        $job = Job::factory()->create(['customer_id' => $customer->id, 'trucks_needed' => 5]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'new_job_posted',
            'related_job_id' => $job->id,
        ]);
    }

    /**
     * Bulk Cargo epic, corrected by Multi-Company Split Awards: a follower
     * with zero verified trucks structurally can never bid on anything and
     * shouldn't be notified at all — pure noise otherwise.
     */
    public function test_a_following_company_with_no_verified_trucks_is_not_notified(): void
    {
        Queue::fake();

        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        CustomerFollow::create(['transporter_company_id' => $company->id, 'customer_id' => $customer->id]);

        Job::factory()->create(['customer_id' => $customer->id, 'trucks_needed' => 5]);

        $this->assertDatabaseMissing('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'new_job_posted',
        ]);
    }

    public function test_a_pending_companys_follow_does_not_notify_it(): void
    {
        Queue::fake();

        $customer = User::factory()->create();
        $pending = TransporterCompany::factory()->create();
        CustomerFollow::create(['transporter_company_id' => $pending->id, 'customer_id' => $customer->id]);

        Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertDatabaseMissing('notifications', [
            'user_id' => $pending->owner_user_id,
            'type' => 'new_job_posted',
        ]);
    }

    public function test_following_one_customer_does_not_notify_for_a_different_customers_job(): void
    {
        Queue::fake();

        $followed = User::factory()->create();
        $notFollowed = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        CustomerFollow::create(['transporter_company_id' => $company->id, 'customer_id' => $followed->id]);

        Job::factory()->create(['customer_id' => $notFollowed->id]);

        $this->assertDatabaseMissing('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'new_job_posted',
        ]);
    }

    /**
     * Phase 5 polish: cancelling a job before any bid ever existed must
     * never leave a follower with a stray bid-related notification (there
     * were never any bids to notify about) or a second, spurious
     * new_job_posted — already correct by construction (BidObserver only
     * ever fires from a real bid row, and this cancellation path creates
     * none), this locks that in explicitly rather than leaving it implicit.
     */
    public function test_cancelling_a_job_before_any_bid_produces_no_extra_notifications(): void
    {
        Queue::fake();

        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        Truck::factory()->approved()->for($company, 'company')->create();
        CustomerFollow::create(['transporter_company_id' => $company->id, 'customer_id' => $customer->id]);

        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);
        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/cancel")->assertOk();

        $this->assertSame(
            1,
            Notification::where('user_id', $company->owner_user_id)->where('related_job_id', $job->id)->count()
        );
        $this->assertDatabaseMissing('notifications', ['related_job_id' => $job->id, 'type' => 'bid_accepted']);
        $this->assertDatabaseMissing('notifications', ['related_job_id' => $job->id, 'type' => 'bid_not_selected']);
    }

    public function test_a_company_that_disabled_new_job_matches_is_not_notified_even_when_following(): void
    {
        Queue::fake();

        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        CustomerFollow::create(['transporter_company_id' => $company->id, 'customer_id' => $customer->id]);
        User::where('id', $company->owner_user_id)->update([
            'notification_preferences' => ['new_job_matches' => false],
        ]);

        Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertDatabaseMissing('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'new_job_posted',
        ]);
    }
}
