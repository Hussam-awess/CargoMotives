<?php

namespace Tests\Feature\Profiles;

use App\Models\CustomerFollow;
use App\Models\Job;
use App\Models\JobReview;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerProfileTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    public function test_shows_the_customers_public_profile(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create(['full_name' => 'Amina Hassan', 'company_name' => 'Amina Textiles Ltd']);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $response->assertOk()
            ->assertJsonPath('data.id', $customer->id)
            ->assertJsonPath('data.full_name', 'Amina Hassan')
            ->assertJsonPath('data.company_name', 'Amina Textiles Ltd')
            ->assertJsonPath('data.rating_count', 0)
            ->assertJsonPath('data.average_rating', null)
            ->assertJsonPath('data.completed_jobs_count', 0)
            ->assertJsonPath('data.cancelled_jobs_count', 0);
    }

    public function test_exposes_the_customers_personal_avatar(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create(['avatar_url' => 'users/avatars/fake-avatar.jpg']);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $response->assertOk();
        $this->assertNotNull($response->json('data.avatar_url'));
    }

    public function test_avatar_is_null_when_the_customer_never_uploaded_one(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create(['avatar_url' => null]);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $response->assertOk()->assertJsonPath('data.avatar_url', null);
    }

    public function test_never_exposes_phone_or_email(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create();

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $data = $response->json('data');
        $this->assertArrayNotHasKey('phone_number', $data);
        $this->assertArrayNotHasKey('email', $data);
        // No verification badge and no location — see
        // CustomerProfileResource's docblock for why neither is real here.
        $this->assertArrayNotHasKey('verified', $data);
        $this->assertArrayNotHasKey('location', $data);
    }

    public function test_completed_and_cancelled_job_counts_are_accurate(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create();
        Job::factory()->count(2)->create(['customer_id' => $customer->id, 'status' => 'completed']);
        Job::factory()->create(['customer_id' => $customer->id, 'status' => 'cancelled']);
        Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $response->assertOk()
            ->assertJsonPath('data.completed_jobs_count', 2)
            ->assertJsonPath('data.cancelled_jobs_count', 1);
    }

    public function test_average_rating_reflects_persisted_stats(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $viewer->transporterCompany->id, 'status' => 'completed']);
        $this->actingAs($viewer)->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 4])->assertCreated();

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $response->assertOk();
        $this->assertEquals(4.0, (float) $response->json('data.average_rating'));
        $this->assertSame(1, $response->json('data.rating_count'));
    }

    public function test_recent_completed_jobs_never_reveal_the_transporter(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create();
        Job::factory()->create([
            'customer_id' => $customer->id,
            'assigned_company_id' => $viewer->transporterCompany->id,
            'status' => 'completed',
            'completed_at' => now(),
            'pickup_address' => 'Kariakoo, Dar es Salaam',
            'dropoff_address' => 'Mbezi Beach, Dar es Salaam',
        ]);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $response->assertOk();
        $recent = $response->json('data.recent_completed_jobs');
        $this->assertCount(1, $recent);
        $this->assertSame('Kariakoo → Mbezi Beach', $recent[0]['route']);
        $this->assertArrayNotHasKey('id', $recent[0]);
        $this->assertArrayNotHasKey('assigned_company_name', $recent[0]);
    }

    public function test_recent_reviews_never_reveal_the_rater(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $viewer->transporterCompany->id, 'status' => 'completed']);
        $this->actingAs($viewer)->postJson("/api/jobs/{$job->id}/reviews", ['rating' => 5, 'comment' => 'Great customer.'])->assertCreated();

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $review = $response->json('data.recent_reviews')[0];
        $this->assertSame(5, $review['rating']);
        $this->assertSame('Great customer.', $review['comment']);
        $this->assertArrayNotHasKey('rater_name', $review);
        $this->assertArrayNotHasKey('rater_user_id', $review);
    }

    public function test_is_following_is_present_and_accurate_for_a_transporter_viewer(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create();

        $notFollowing = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");
        $notFollowing->assertOk()->assertJsonPath('data.is_following', false);

        CustomerFollow::create(['transporter_company_id' => $viewer->transporterCompany->id, 'customer_id' => $customer->id]);

        $following = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");
        $following->assertOk()->assertJsonPath('data.is_following', true);
    }

    public function test_is_following_is_absent_for_a_customer_viewer(): void
    {
        $viewer = User::factory()->create();
        $customer = User::factory()->create();

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}");

        $response->assertOk();
        $this->assertArrayNotHasKey('is_following', $response->json('data'));
    }

    public function test_viewing_a_transporter_companys_account_as_a_customer_profile_404s(): void
    {
        $viewer = $this->approvedCompanyUser();
        $otherCompanyOwner = User::factory()->transporterCompany()->create();

        $this->actingAs($viewer)
            ->getJson("/api/profiles/customers/{$otherCompanyOwner->id}")
            ->assertNotFound();
    }

    public function test_the_full_reviews_list_is_paginated_and_anonymous(): void
    {
        $viewer = $this->approvedCompanyUser();
        $customer = User::factory()->create();
        JobReview::create([
            'job_id' => Job::factory()->create(['customer_id' => $customer->id, 'status' => 'completed'])->id,
            'rater_type' => 'transporter_company',
            'rater_user_id' => $viewer->id,
            'ratee_customer_id' => $customer->id,
            'rating' => 3,
            'comment' => 'Okay experience.',
        ]);

        $response = $this->actingAs($viewer)->getJson("/api/profiles/customers/{$customer->id}/reviews");

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
        $this->assertArrayNotHasKey('rater_name', $response->json('data.0'));
    }

    public function test_shows_the_customers_plus_badge_status(): void
    {
        $viewer = $this->approvedCompanyUser();
        $plusCustomer = User::factory()->create(['is_featured' => true]);
        $standardCustomer = User::factory()->create(['is_featured' => false]);

        $this->actingAs($viewer)
            ->getJson("/api/profiles/customers/{$plusCustomer->id}")
            ->assertOk()
            ->assertJsonPath('data.is_featured', true);

        $this->actingAs($viewer)
            ->getJson("/api/profiles/customers/{$standardCustomer->id}")
            ->assertOk()
            ->assertJsonPath('data.is_featured', false);
    }
}
