<?php

namespace Tests\Feature\Jobs;

use App\Models\Bid;
use App\Models\Driver;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Multi-Company Split Awards epic: BidController::accept()'s three-way
 * branch (byte-for-byte Tier 1/2 when one bid covers everything, a new
 * job_awards row when it's partial, cumulative close once every award
 * together covers trucks_needed) and the Tier 3 assignment flow it unlocks.
 *
 * Tier 1/2's own "one bid covers it all, no job_awards row created"
 * behavior is already covered by BidTest::test_accepting_a_bid_assigns_
 * the_job_and_rejects_other_bids (trucks_needed defaults to 1) — not
 * duplicated here.
 */
class JobAwardTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(int $verifiedTrucks = 1): User
    {
        $user = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($user, 'owner')->create();
        Truck::factory()->approved()->count($verifiedTrucks)->for($company, 'company')->create();

        return $user;
    }

    public function test_accepting_a_partial_bid_creates_an_award_and_keeps_the_job_open(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open', 'trucks_needed' => 20]);
        $companyA = $this->approvedCompanyUser(8);
        $bid = Bid::factory()->create([
            'job_id' => $job->id,
            'transporter_company_id' => $companyA->transporterCompany->id,
            'trucks_offered' => 8,
            'price' => 400000,
        ]);

        $response = $this->actingAs($customer)->postJson("/api/bids/{$bid->id}/accept");

        $response->assertOk()->assertJsonPath('job.status', 'open');

        $this->assertDatabaseHas('job_awards', [
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $companyA->transporterCompany->id,
            'trucks_offered' => 8,
        ]);
        $this->assertDatabaseHas('jobs', [
            'id' => $job->id,
            'status' => 'open',
            // No single "the" company once this could become a split job.
            'assigned_company_id' => null,
        ]);
    }

    public function test_the_covering_award_closes_the_job_and_rejects_remaining_pending_bids(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open', 'trucks_needed' => 20]);

        $companyA = $this->approvedCompanyUser(8);
        $bidA = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyA->transporterCompany->id, 'trucks_offered' => 8]);
        $this->actingAs($customer)->postJson("/api/bids/{$bidA->id}/accept")->assertOk();

        $companyB = $this->approvedCompanyUser(12);
        $bidB = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyB->transporterCompany->id, 'trucks_offered' => 12]);

        $companyC = $this->approvedCompanyUser(5);
        $stillPendingBid = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyC->transporterCompany->id, 'trucks_offered' => 5]);

        $response = $this->actingAs($customer)->postJson("/api/bids/{$bidB->id}/accept");

        $response->assertOk()->assertJsonPath('job.status', 'assigned');

        $this->assertDatabaseHas('job_awards', ['job_id' => $job->id, 'transporter_company_id' => $companyB->transporterCompany->id, 'trucks_offered' => 12]);
        $this->assertDatabaseHas('jobs', ['id' => $job->id, 'status' => 'assigned']);
        $this->assertDatabaseHas('bids', ['id' => $stillPendingBid->id, 'status' => 'rejected']);
        // Company A's own award is untouched by Company B's acceptance.
        $this->assertDatabaseHas('job_awards', ['job_id' => $job->id, 'transporter_company_id' => $companyA->transporterCompany->id, 'trucks_offered' => 8]);
    }

    public function test_a_bid_offering_more_than_the_remaining_capacity_cannot_be_accepted(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open', 'trucks_needed' => 20]);

        $companyA = $this->approvedCompanyUser(8);
        $bidA = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyA->transporterCompany->id, 'trucks_offered' => 8]);
        $this->actingAs($customer)->postJson("/api/bids/{$bidA->id}/accept")->assertOk();

        $companyB = $this->approvedCompanyUser(15);
        $bidB = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyB->transporterCompany->id, 'trucks_offered' => 15]);

        $this->actingAs($customer)
            ->postJson("/api/bids/{$bidB->id}/accept")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('trucks_offered');
    }

    /**
     * The hard blocker this epic had to fix: a Tier 3 company's award keeps
     * the job's own status at 'open' (awaiting the rest of its capacity),
     * so it must still be able to assign its own trucks immediately rather
     * than getting a 404 (authorizeCompanyOwnership) or being blocked by a
     * status gate meant for the legacy single-company path.
     */
    public function test_an_awarded_company_can_assign_trucks_to_its_own_roster_while_the_job_stays_open(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open', 'trucks_needed' => 20]);

        $companyA = $this->approvedCompanyUser(8);
        $companyAId = $companyA->transporterCompany->id;
        $bidA = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyAId, 'trucks_offered' => 8]);
        $this->actingAs($customer)->postJson("/api/bids/{$bidA->id}/accept")->assertOk();

        $this->assertSame('open', $job->fresh()->status);

        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $companyAId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $companyAId]);

        $response = $this->actingAs($companyA)->postJson("/api/company/jobs/{$job->id}/assign", [
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
        ]);

        $response->assertCreated()->assertJsonPath('data.status', 'active');

        $award = JobAward::where('job_id', $job->id)->where('transporter_company_id', $companyAId)->firstOrFail();
        $this->assertDatabaseHas('job_truck_assignments', [
            'job_award_id' => $award->id,
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
            'is_lead' => true,
        ]);
        $this->assertSame('on_job', $truck->fresh()->current_status);
        // Tier 3 never touches the job's own legacy scalar fields — there's
        // no single "the" truck once 2+ companies could each have one.
        $this->assertNull($job->fresh()->assigned_truck_id);
    }

    /**
     * A company holding no award (and not the legacy sole-assigned company)
     * gets today's ordinary 404 — the fix only widens ownership to include
     * awarded companies, it doesn't loosen it further.
     */
    public function test_a_company_with_no_award_cannot_assign_trucks_to_someone_elses_job(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open', 'trucks_needed' => 20]);

        $companyA = $this->approvedCompanyUser(8);
        $bidA = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyA->transporterCompany->id, 'trucks_offered' => 8]);
        $this->actingAs($customer)->postJson("/api/bids/{$bidA->id}/accept")->assertOk();

        $bystander = $this->approvedCompanyUser(3);
        $bystanderId = $bystander->transporterCompany->id;
        $truck = Truck::factory()->approved()->create(['transporter_company_id' => $bystanderId, 'current_status' => 'idle']);
        $driver = Driver::factory()->create(['transporter_company_id' => $bystanderId]);

        $this->actingAs($bystander)
            ->postJson("/api/company/jobs/{$job->id}/assign", ['truck_id' => $truck->id, 'driver_id' => $driver->id])
            ->assertNotFound();
    }
}
