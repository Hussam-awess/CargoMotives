<?php

namespace Tests\Feature\Jobs;

use App\Models\Bid;
use App\Models\Job;
use App\Models\Notification;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use App\Services\Geo\GeoPoint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * "Find a return load" (CompanyJobController::returnLoadSuggestions()) and
 * the one-tap claim on top of it (claimReturnLoad()) — a match at the
 * job's own posted price, with no competitive bidding. The customer still
 * explicitly confirms via the ordinary BidController::accept() flow.
 */
class ReturnLoadClaimTest extends TestCase
{
    use RefreshDatabase;

    private function featuredCompanyUser(array $companyAttributes = []): User
    {
        $user = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($user, 'owner')->create([
            'is_featured' => true,
            'featured_until' => now()->addMonth(),
            ...$companyAttributes,
        ]);
        Truck::factory()->approved()->for($company, 'company')->create();

        return $user;
    }

    /**
     * A job this company just delivered — the "from" side of a return
     * load. Its dropoff point is what returnLoadSuggestions() matches
     * other jobs' pickup points against.
     */
    private function deliveredJob(int $companyId): Job
    {
        return Job::factory()->create([
            'assigned_company_id' => $companyId,
            'status' => 'completed',
        ]);
    }

    public function test_a_non_featured_company_is_forbidden(): void
    {
        $companyUser = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyUser, 'owner')->create(['is_featured' => false]);
        $fromJob = $this->deliveredJob($company->id);

        $this->actingAs($companyUser)
            ->getJson("/api/company/jobs/{$fromJob->id}/return-load-suggestions")
            ->assertForbidden();
    }

    public function test_suggestions_include_nearby_open_jobs_with_or_without_a_stated_price(): void
    {
        // A job with no stated price is still a legitimate nearby match —
        // the client just can't offer the one-tap "Claim" action for it
        // (claimReturnLoad() itself rejects claiming one, tested below).
        $companyUser = $this->featuredCompanyUser();
        $company = $companyUser->transporterCompany;
        $fromJob = $this->deliveredJob($company->id);

        $withPrice = Job::factory()->create(['status' => 'open', 'budget_price' => 400000]);
        $withoutPrice = Job::factory()->create(['status' => 'open', 'budget_price' => null]);

        $response = $this->actingAs($companyUser)->getJson("/api/company/jobs/{$fromJob->id}/return-load-suggestions");

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($withPrice->id));
        $this->assertTrue($ids->contains($withoutPrice->id));
    }

    public function test_claiming_a_matched_job_with_no_stated_price_is_rejected(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $fromJob = $this->deliveredJob($companyUser->transporterCompany->id);
        $target = Job::factory()->create(['status' => 'open', 'budget_price' => null]);

        $this->actingAs($companyUser)
            ->postJson("/api/company/jobs/{$target->id}/claim-return-load", ['from_job_id' => $fromJob->id])
            ->assertUnprocessable();

        $this->assertDatabaseMissing('bids', ['job_id' => $target->id]);
    }

    public function test_a_job_far_from_the_delivery_point_is_not_suggested(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $company = $companyUser->transporterCompany;
        $fromJob = $this->deliveredJob($company->id);

        // Mwanza, ~1000km from the factory's Dar es Salaam jobs — well
        // outside the 50km return-load radius.
        $farAway = Job::factory()->create([
            'status' => 'open',
            'budget_price' => 400000,
            'pickup_location' => (new GeoPoint(-2.516, 32.900))->toInsertExpression(),
        ]);

        $response = $this->actingAs($companyUser)->getJson("/api/company/jobs/{$fromJob->id}/return-load-suggestions");

        $response->assertOk();
        $this->assertFalse(collect($response->json('data'))->pluck('id')->contains($farAway->id));
    }

    public function test_a_company_with_a_home_region_sees_matching_jobs_ranked_first(): void
    {
        $companyUser = $this->featuredCompanyUser(['home_region' => 'Mwanza']);
        $company = $companyUser->transporterCompany;
        $fromJob = $this->deliveredJob($company->id);

        $elsewhere = Job::factory()->create(['status' => 'open', 'budget_price' => 300000, 'dropoff_address' => 'Kariakoo, Dar es Salaam']);
        $towardHome = Job::factory()->create(['status' => 'open', 'budget_price' => 300000, 'dropoff_address' => 'Ilemela, Mwanza']);

        $response = $this->actingAs($companyUser)->getJson("/api/company/jobs/{$fromJob->id}/return-load-suggestions");

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->values();
        $this->assertSame($towardHome->id, $ids->first(), 'the job heading toward the home region should sort first');
        $this->assertTrue($ids->contains($elsewhere->id), 'a non-matching job should still be suggested, just not first');
    }

    public function test_claiming_a_matched_job_creates_a_pending_bid_at_its_posted_price(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $company = $companyUser->transporterCompany;
        $fromJob = $this->deliveredJob($company->id);
        $target = Job::factory()->create(['status' => 'open', 'budget_price' => 450000]);

        $response = $this->actingAs($companyUser)->postJson("/api/company/jobs/{$target->id}/claim-return-load", [
            'from_job_id' => $fromJob->id,
        ]);

        $response->assertOk()
            ->assertJsonPath('data.price', 450000)
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.is_return_load_claim', true);

        $this->assertDatabaseHas('bids', [
            'job_id' => $target->id,
            'transporter_company_id' => $company->id,
            'is_return_load_claim' => true,
        ]);
    }

    public function test_claiming_sends_the_customer_a_distinct_notification(): void
    {
        $customer = User::factory()->create();
        $companyUser = $this->featuredCompanyUser();
        $fromJob = $this->deliveredJob($companyUser->transporterCompany->id);
        $target = Job::factory()->create(['status' => 'open', 'budget_price' => 450000, 'customer_id' => $customer->id]);

        $this->actingAs($companyUser)
            ->postJson("/api/company/jobs/{$target->id}/claim-return-load", ['from_job_id' => $fromJob->id])
            ->assertOk();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $customer->id,
            'type' => 'return_load_claim',
            'related_job_id' => $target->id,
        ]);
        $this->assertSame(0, Notification::where('user_id', $customer->id)->where('type', 'new_bid')->count());
    }

    public function test_claiming_a_job_too_far_from_the_delivery_point_is_rejected(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $fromJob = $this->deliveredJob($companyUser->transporterCompany->id);
        $tooFar = Job::factory()->create([
            'status' => 'open',
            'budget_price' => 300000,
            'pickup_location' => (new GeoPoint(-2.516, 32.900))->toInsertExpression(),
        ]);

        $this->actingAs($companyUser)
            ->postJson("/api/company/jobs/{$tooFar->id}/claim-return-load", ['from_job_id' => $fromJob->id])
            ->assertUnprocessable();

        $this->assertDatabaseMissing('bids', ['job_id' => $tooFar->id]);
    }

    public function test_claiming_using_a_delivery_job_that_does_not_belong_to_the_company_is_rejected(): void
    {
        $companyUser = $this->featuredCompanyUser();
        $someoneElsesFromJob = $this->deliveredJob(TransporterCompany::factory()->approved()->create()->id);
        $target = Job::factory()->create(['status' => 'open', 'budget_price' => 300000]);

        $this->actingAs($companyUser)
            ->postJson("/api/company/jobs/{$target->id}/claim-return-load", ['from_job_id' => $someoneElsesFromJob->id])
            ->assertNotFound();
    }

    public function test_claiming_fails_when_the_companys_verified_fleet_is_too_small(): void
    {
        $companyUser = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyUser, 'owner')->create([
            'is_featured' => true,
            'featured_until' => now()->addMonth(),
        ]);
        // Deliberately no approved trucks at all.
        $fromJob = $this->deliveredJob($company->id);
        $target = Job::factory()->create(['status' => 'open', 'budget_price' => 300000, 'trucks_needed' => 1]);

        $this->actingAs($companyUser)
            ->postJson("/api/company/jobs/{$target->id}/claim-return-load", ['from_job_id' => $fromJob->id])
            ->assertUnprocessable();
    }

    public function test_the_customer_can_still_accept_a_claimed_bid_like_any_other(): void
    {
        $customer = User::factory()->create();
        $companyUser = $this->featuredCompanyUser();
        $fromJob = $this->deliveredJob($companyUser->transporterCompany->id);
        $target = Job::factory()->create(['status' => 'open', 'budget_price' => 300000, 'customer_id' => $customer->id]);

        $this->actingAs($companyUser)
            ->postJson("/api/company/jobs/{$target->id}/claim-return-load", ['from_job_id' => $fromJob->id])
            ->assertOk();

        $bid = Bid::where('job_id', $target->id)->firstOrFail();

        $this->actingAs($customer)
            ->postJson("/api/bids/{$bid->id}/accept")
            ->assertOk()
            ->assertJsonPath('job.status', 'assigned')
            ->assertJsonPath('job.assigned_company_id', $companyUser->transporterCompany->id);
    }
}
