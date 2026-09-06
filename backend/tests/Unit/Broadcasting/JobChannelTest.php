<?php

namespace Tests\Unit\Broadcasting;

use App\Broadcasting\JobChannel;
use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * See JobChannel's docblock for why this is a unit test against the class
 * directly, not a feature test hitting /api/broadcasting/auth: that route
 * only performs real channel authorization when a live Pusher-protocol
 * broadcaster driver is configured, which the rest of the suite
 * deliberately doesn't do (BROADCAST_CONNECTION=null in phpunit.xml).
 */
class JobChannelTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_jobs_own_customer_can_join(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertTrue((new JobChannel)->join($customer, $job->id));
    }

    public function test_a_different_customer_cannot_join(): void
    {
        $customer = User::factory()->create();
        $otherCustomer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertFalse((new JobChannel)->join($otherCustomer, $job->id));
    }

    public function test_a_nonexistent_job_denies_everyone(): void
    {
        $customer = User::factory()->create();

        $this->assertFalse((new JobChannel)->join($customer, 999999));
    }
}
