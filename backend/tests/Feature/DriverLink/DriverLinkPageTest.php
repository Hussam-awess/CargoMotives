<?php

namespace Tests\Feature\DriverLink;

use App\Models\Bid;
use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\JobTruckAssignment;
use App\Models\TransporterCompany;
use App\Models\Truck;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * The no-login, server-rendered Driver Link page (AppFlow §4). These hit
 * plain web routes (routes/web.php), not the JSON API — a token in the
 * URL is the entire authorization, so there's no actingAs() anywhere here.
 */
class DriverLinkPageTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_valid_link_shows_the_job_summary_and_next_action(): void
    {
        $job = Job::factory()->assigned()->create(['pickup_address' => 'Kariakoo, Dar es Salaam']);
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $response = $this->get("/driver-link/{$link->token}");

        $response->assertOk()
            ->assertSee('Kariakoo, Dar es Salaam')
            ->assertSee('Mark as En Route to Pickup')
            ->assertSee('Submit Proof of Delivery');
    }

    public function test_an_unknown_token_shows_a_not_found_page(): void
    {
        $this->get('/driver-link/not-a-real-token')
            ->assertOk()
            ->assertSee("We couldn't find this link", false);
    }

    public function test_an_expired_link_shows_an_expired_page(): void
    {
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->expired()->create(['job_id' => $job->id]);

        $this->get("/driver-link/{$link->token}")
            ->assertOk()
            ->assertSee('This link has expired');
    }

    public function test_an_already_used_link_shows_the_submitted_confirmation(): void
    {
        $job = Job::factory()->create(['status' => 'delivered']);
        $link = DriverLink::factory()->used()->create(['job_id' => $job->id]);

        $this->get("/driver-link/{$link->token}")
            ->assertOk()
            ->assertSee('Delivered — thank you!');
    }

    public function test_the_driver_can_advance_the_job_status_forward_only(): void
    {
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertRedirect();
        $this->assertSame('en_route_pickup', $job->fresh()->status);

        // Backward move is rejected.
        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertSessionHasErrors('status');
        $this->assertSame('en_route_pickup', $job->fresh()->status);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'in_transit'])
            ->assertRedirect();
        $this->assertSame('in_transit', $job->fresh()->status);
    }

    public function test_status_updates_are_rejected_once_the_link_has_expired(): void
    {
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->expired()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertStatus(410);
        $this->assertSame('assigned', $job->fresh()->status);
    }

    public function test_submitting_proof_of_delivery_marks_the_job_delivered_and_the_link_used(): void
    {
        Storage::fake('local');
        $job = Job::factory()->assigned()->create();
        $driver = Driver::factory()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);

        $response = $this->post("/driver-link/{$link->token}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
            'recipient_name' => 'Asha Mwinyi',
            'notes' => 'Left at the front desk.',
        ]);

        $response->assertRedirect("/driver-link/{$link->token}");

        $job->refresh();
        $link->refresh();
        $this->assertSame('delivered', $job->status);
        $this->assertSame('used', $link->status);
        $this->assertNotNull($link->used_at);
        $this->assertDatabaseHas('proof_of_deliveries', [
            'job_id' => $job->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'recipient_name' => 'Asha Mwinyi',
        ]);
    }

    public function test_proof_of_delivery_requires_at_least_one_photo(): void
    {
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/proof-of-delivery", ['recipient_name' => 'Asha Mwinyi'])
            ->assertSessionHasErrors('photos');
        $this->assertSame('assigned', $job->fresh()->status);
    }

    public function test_a_used_links_proof_of_delivery_route_cannot_be_submitted_again(): void
    {
        Storage::fake('local');
        $job = Job::factory()->create(['status' => 'delivered']);
        $link = DriverLink::factory()->used()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
        ])->assertStatus(410);
    }

    /**
     * Bulk Cargo epic: on a multi-truck job, only the lead truck's driver
     * link can advance the job's one shared status — every other roster
     * member's link is read-only for status/proof-of-delivery purposes.
     */
    public function test_a_non_lead_roster_members_link_cannot_advance_status(): void
    {
        $job = Job::factory()->assigned()->create(['trucks_needed' => 2]);
        $truck = Truck::factory()->approved()->create();
        $driver = Driver::factory()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);
        JobTruckAssignment::create([
            'job_id' => $job->id,
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'is_lead' => false,
            'assigned_at' => now(),
        ]);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertForbidden();
        $this->assertSame('assigned', $job->fresh()->status);
    }

    public function test_a_non_lead_roster_members_link_cannot_submit_proof_of_delivery(): void
    {
        Storage::fake('local');
        $job = Job::factory()->assigned()->create(['trucks_needed' => 2]);
        $truck = Truck::factory()->approved()->create();
        $driver = Driver::factory()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);
        JobTruckAssignment::create([
            'job_id' => $job->id,
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'is_lead' => false,
            'assigned_at' => now(),
        ]);

        $this->post("/driver-link/{$link->token}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
        ])->assertForbidden();
        $this->assertSame('assigned', $job->fresh()->status);
    }

    public function test_the_lead_roster_members_link_can_still_advance_status_on_a_multi_truck_job(): void
    {
        $job = Job::factory()->assigned()->create(['trucks_needed' => 2]);
        $truck = Truck::factory()->approved()->create();
        $driver = Driver::factory()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);
        JobTruckAssignment::create([
            'job_id' => $job->id,
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'is_lead' => true,
            'assigned_at' => now(),
        ]);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertRedirect();
        $this->assertSame('en_route_pickup', $job->fresh()->status);
    }

    public function test_an_ordinary_single_truck_jobs_link_is_completely_unaffected_by_the_lead_check(): void
    {
        // trucks_needed defaults to 1 — no JobTruckAssignment row exists at
        // all, so mayControlStatus() must short-circuit true without
        // needing one, exactly as before the Bulk Cargo epic.
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertRedirect();
        $this->assertSame('en_route_pickup', $job->fresh()->status);
    }

    /**
     * Multi-Company Split Awards epic: a Tier 3 job legitimately stays
     * 'open' while a company's own award is already in flight — its lead
     * link must advance the AWARD's status, never the job's (there's no
     * single "the" status once 2+ companies could each have one).
     */
    public function test_an_awards_lead_link_advances_the_awards_own_status_not_the_jobs(): void
    {
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 20]);
        $company = TransporterCompany::factory()->approved()->create();
        $bid = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $company->id, 'trucks_offered' => 8]);
        $award = JobAward::create([
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $company->id,
            'trucks_offered' => 8,
            'agreed_price' => 400000,
        ]);
        $truck = Truck::factory()->approved()->create();
        $driver = Driver::factory()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);
        JobTruckAssignment::create([
            'job_id' => $job->id,
            'job_award_id' => $award->id,
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'is_lead' => true,
            'assigned_at' => now(),
        ]);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertRedirect();

        $this->assertSame('en_route_pickup', $award->fresh()->status);
        $this->assertSame('open', $job->fresh()->status);
    }

    /**
     * Same epic: proof of delivery on an award-scoped link marks that
     * award (not the job) delivered, and stamps job_award_id on the
     * ProofOfDelivery row so it's attributable to the right company.
     */
    public function test_an_awards_lead_link_can_submit_proof_of_delivery_scoped_to_that_award(): void
    {
        Storage::fake('local');
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 20]);
        $company = TransporterCompany::factory()->approved()->create();
        $bid = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $company->id, 'trucks_offered' => 8]);
        $award = JobAward::create([
            'job_id' => $job->id,
            'bid_id' => $bid->id,
            'transporter_company_id' => $company->id,
            'trucks_offered' => 8,
            'agreed_price' => 400000,
        ]);
        $truck = Truck::factory()->approved()->create();
        $driver = Driver::factory()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);
        JobTruckAssignment::create([
            'job_id' => $job->id,
            'job_award_id' => $award->id,
            'truck_id' => $truck->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'is_lead' => true,
            'assigned_at' => now(),
        ]);

        $response = $this->post("/driver-link/{$link->token}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
            'recipient_name' => 'Asha Mwinyi',
        ]);

        $response->assertRedirect("/driver-link/{$link->token}");
        $this->assertSame('delivered', $award->fresh()->status);
        $this->assertSame('open', $job->fresh()->status);
        $this->assertDatabaseHas('proof_of_deliveries', [
            'job_id' => $job->id,
            'job_award_id' => $award->id,
            'driver_id' => $driver->id,
        ]);
    }

    /**
     * Regression test for a real bug caught during live verification: the
     * original proof_of_deliveries.job_id unique constraint (one PoD per
     * job, from before this epic) still applied to every row regardless of
     * job_award_id, so a job's SECOND award submitting its own proof of
     * delivery hit a duplicate-key error on the same job_id — see the
     * "fix_proof_of_deliveries_unique_constraint_for_awards" migration.
     */
    public function test_two_different_awards_on_the_same_job_can_each_submit_their_own_proof_of_delivery(): void
    {
        Storage::fake('local');
        $job = Job::factory()->create(['status' => 'open', 'trucks_needed' => 20]);

        $companyA = TransporterCompany::factory()->approved()->create();
        $bidA = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyA->id, 'trucks_offered' => 8]);
        $awardA = JobAward::create([
            'job_id' => $job->id, 'bid_id' => $bidA->id, 'transporter_company_id' => $companyA->id,
            'trucks_offered' => 8, 'agreed_price' => 400000,
        ]);
        $linkA = DriverLink::factory()->create(['job_id' => $job->id]);
        JobTruckAssignment::create([
            'job_id' => $job->id, 'job_award_id' => $awardA->id, 'truck_id' => Truck::factory()->approved()->create()->id,
            'driver_id' => Driver::factory()->create()->id, 'driver_link_id' => $linkA->id, 'is_lead' => true, 'assigned_at' => now(),
        ]);

        $companyB = TransporterCompany::factory()->approved()->create();
        $bidB = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $companyB->id, 'trucks_offered' => 12]);
        $awardB = JobAward::create([
            'job_id' => $job->id, 'bid_id' => $bidB->id, 'transporter_company_id' => $companyB->id,
            'trucks_offered' => 12, 'agreed_price' => 600000,
        ]);
        $linkB = DriverLink::factory()->create(['job_id' => $job->id]);
        JobTruckAssignment::create([
            'job_id' => $job->id, 'job_award_id' => $awardB->id, 'truck_id' => Truck::factory()->approved()->create()->id,
            'driver_id' => Driver::factory()->create()->id, 'driver_link_id' => $linkB->id, 'is_lead' => true, 'assigned_at' => now(),
        ]);

        $this->post("/driver-link/{$linkA->token}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('a.jpg', 200, 'image/jpeg')],
        ])->assertRedirect();

        $this->post("/driver-link/{$linkB->token}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('b.jpg', 200, 'image/jpeg')],
        ])->assertRedirect();

        $this->assertSame('delivered', $awardA->fresh()->status);
        $this->assertSame('delivered', $awardB->fresh()->status);
        $this->assertDatabaseHas('proof_of_deliveries', ['job_id' => $job->id, 'job_award_id' => $awardA->id]);
        $this->assertDatabaseHas('proof_of_deliveries', ['job_id' => $job->id, 'job_award_id' => $awardB->id]);
    }
}
