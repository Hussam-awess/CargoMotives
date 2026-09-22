<?php

namespace Tests\Feature\Console;

use App\Models\Bid;
use App\Models\Job;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class NotifyBiddingClosedTest extends TestCase
{
    use RefreshDatabase;

    public function test_notifies_no_bids_when_the_deadline_passed_with_none(): void
    {
        Queue::fake();

        $job = Job::factory()->create(['status' => 'open', 'bidding_expires_at' => now()->subHour()]);

        $this->artisan('jobs:notify-bidding-closed');

        $this->assertDatabaseHas('notifications', [
            'user_id' => $job->customer_id,
            'type' => 'bidding_closed_no_bids',
            'related_job_id' => $job->id,
        ]);
        $this->assertNotNull($job->fresh()->bidding_expiry_notified_at);
    }

    public function test_notifies_select_a_transporter_when_pending_bids_exist(): void
    {
        Queue::fake();

        $job = Job::factory()->create(['status' => 'open', 'bidding_expires_at' => now()->subHour()]);
        Bid::factory()->create(['job_id' => $job->id, 'status' => 'pending']);

        $this->artisan('jobs:notify-bidding-closed');

        $this->assertDatabaseHas('notifications', [
            'user_id' => $job->customer_id,
            'type' => 'bidding_closed_has_bids',
            'related_job_id' => $job->id,
        ]);
        $this->assertDatabaseMissing('notifications', ['user_id' => $job->customer_id, 'type' => 'bidding_closed_no_bids']);
    }

    public function test_a_withdrawn_bid_alone_still_counts_as_no_bids(): void
    {
        Queue::fake();

        $job = Job::factory()->create(['status' => 'open', 'bidding_expires_at' => now()->subHour()]);
        Bid::factory()->withdrawn()->create(['job_id' => $job->id]);

        $this->artisan('jobs:notify-bidding-closed');

        $this->assertDatabaseHas('notifications', ['user_id' => $job->customer_id, 'type' => 'bidding_closed_no_bids']);
    }

    public function test_never_double_sends_once_already_notified(): void
    {
        Queue::fake();

        $job = Job::factory()->create([
            'status' => 'open',
            'bidding_expires_at' => now()->subHour(),
            'bidding_expiry_notified_at' => now()->subMinutes(5),
        ]);

        $this->artisan('jobs:notify-bidding-closed');

        $this->assertDatabaseMissing('notifications', ['user_id' => $job->customer_id]);
    }

    public function test_does_not_touch_a_job_whose_deadline_has_not_passed_yet(): void
    {
        Queue::fake();

        $job = Job::factory()->create(['status' => 'open', 'bidding_expires_at' => now()->addHour()]);

        $this->artisan('jobs:notify-bidding-closed');

        $this->assertDatabaseMissing('notifications', ['user_id' => $job->customer_id]);
        $this->assertNull($job->fresh()->bidding_expiry_notified_at);
    }

    public function test_does_not_touch_a_job_with_no_deadline_at_all(): void
    {
        Queue::fake();

        $job = Job::factory()->create(['status' => 'open', 'bidding_expires_at' => null]);

        $this->artisan('jobs:notify-bidding-closed');

        $this->assertDatabaseMissing('notifications', ['user_id' => $job->customer_id]);
    }

    public function test_does_not_touch_a_job_that_is_no_longer_open(): void
    {
        Queue::fake();

        $job = Job::factory()->assigned()->create(['bidding_expires_at' => now()->subHour()]);

        $this->artisan('jobs:notify-bidding-closed');

        $this->assertDatabaseMissing('notifications', ['user_id' => $job->customer_id]);
    }
}
