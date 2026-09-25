<?php

namespace Tests\Unit\Services\Jobs;

use App\Models\Bid;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Services\Jobs\ProofOfDeliveryService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProofOfDeliveryServiceTest extends TestCase
{
    use RefreshDatabase;

    private function service(): ProofOfDeliveryService
    {
        return $this->app->make(ProofOfDeliveryService::class);
    }

    public function test_creates_a_proof_of_delivery_and_marks_the_job_delivered(): void
    {
        $job = Job::factory()->assigned()->create(['status' => 'in_transit']);
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $pod = $this->service()->submit($job, null, $link, ['proof/photo.jpg'], 'Asha Mwinyi', 'Left at the gate');

        $this->assertSame('delivered', $job->fresh()->status);
        $this->assertSame('used', $link->fresh()->status);
        $this->assertNotNull($link->fresh()->used_at);
        $this->assertFalse($pod->is_system_generated);
        $this->assertSame(['proof/photo.jpg'], $pod->photo_urls);
        $this->assertSame('Asha Mwinyi', $pod->recipient_name);
        $this->assertDatabaseHas('proof_of_deliveries', [
            'job_id' => $job->id, 'job_award_id' => null, 'driver_id' => $link->driver_id, 'driver_link_id' => $link->id,
        ]);
    }

    public function test_can_submit_with_no_photos_flagged_as_system_generated(): void
    {
        $job = Job::factory()->assigned()->create(['status' => 'in_transit']);
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $pod = $this->service()->submit($job, null, $link, [], null, 'auto note', isSystemGenerated: true);

        $this->assertTrue($pod->is_system_generated);
        $this->assertSame([], $pod->photo_urls);
        $this->assertNull($pod->recipient_name);
        $this->assertSame('delivered', $job->fresh()->status);
    }

    public function test_scopes_to_an_award_when_one_is_given(): void
    {
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 20]);
        $bid = Bid::factory()->for($job)->create(['trucks_offered' => 8]);
        $award = JobAward::create([
            'job_id' => $job->id, 'bid_id' => $bid->id, 'transporter_company_id' => $bid->transporter_company_id,
            'trucks_offered' => 8, 'agreed_price' => $bid->price, 'status' => 'in_transit',
        ]);
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $pod = $this->service()->submit($job, $award, $link, [], null, null);

        $this->assertSame('delivered', $award->fresh()->status);
        $this->assertSame('open', $job->fresh()->status);
        $this->assertSame($award->id, $pod->job_award_id);
    }

    public function test_does_not_re_mark_an_already_used_link(): void
    {
        $job = Job::factory()->assigned()->create(['status' => 'in_transit']);
        $link = DriverLink::factory()->used()->create(['job_id' => $job->id]);
        $originalUsedAt = $link->used_at;

        $this->service()->submit($job, null, $link, [], null, null);

        $this->assertEquals($originalUsedAt->timestamp, $link->fresh()->used_at->timestamp);
    }
}
