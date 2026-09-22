<?php

namespace Tests\Feature\Jobs;

use App\Events\BidPlaced;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * TRD §4: live bid updates on an open job screen — one of exactly two
 * places this app uses WebSockets. Covers the backend half — the event
 * fires with the right payload for the right job. Channel authorization
 * (who's allowed to actually hear it) is unit-tested directly against
 * App\Broadcasting\JobChannel — see tests/Unit/Broadcasting/JobChannelTest
 * and that class's docblock for why. The actual live-in-a-browser behavior
 * is verified manually, the same way file uploads needed a live curl/
 * browser check beyond what an automated test can reasonably cover.
 */
class BidBroadcastTest extends TestCase
{
    use RefreshDatabase;

    public function test_placing_a_bid_dispatches_bid_placed_for_the_jobs_channel(): void
    {
        Event::fake([BidPlaced::class]);

        $companyUser = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyUser, 'owner')->create();
        Truck::factory()->approved()->for($company, 'company')->create();
        $job = Job::factory()->create(['status' => 'open']);

        $this->actingAs($companyUser)
            ->postJson("/api/company/jobs/{$job->id}/bids", ['price' => 500000])
            ->assertCreated();

        Event::assertDispatched(BidPlaced::class, fn (BidPlaced $event) => $event->bid->job_id === $job->id);
    }
}
