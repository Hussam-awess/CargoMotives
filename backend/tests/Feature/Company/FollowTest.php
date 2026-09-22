<?php

namespace Tests\Feature\Company;

use App\Models\CustomerFollow;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FollowTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    public function test_an_approved_company_can_follow_a_customer(): void
    {
        $company = $this->approvedCompanyUser();
        $customer = User::factory()->create();

        $response = $this->actingAs($company)->postJson("/api/company/customers/{$customer->id}/follow");

        $response->assertOk()->assertJsonPath('is_following', true);
        $this->assertDatabaseHas('customer_follows', [
            'transporter_company_id' => $company->transporterCompany->id,
            'customer_id' => $customer->id,
        ]);
    }

    public function test_following_the_same_customer_twice_does_not_create_a_duplicate_row(): void
    {
        $company = $this->approvedCompanyUser();
        $customer = User::factory()->create();

        $this->actingAs($company)->postJson("/api/company/customers/{$customer->id}/follow")->assertOk();
        $this->actingAs($company)->postJson("/api/company/customers/{$customer->id}/follow")->assertOk();

        $this->assertSame(1, CustomerFollow::where('customer_id', $customer->id)->count());
    }

    public function test_a_company_can_unfollow_a_customer(): void
    {
        $company = $this->approvedCompanyUser();
        $customer = User::factory()->create();
        CustomerFollow::create(['transporter_company_id' => $company->transporterCompany->id, 'customer_id' => $customer->id]);

        $response = $this->actingAs($company)->deleteJson("/api/company/customers/{$customer->id}/follow");

        $response->assertOk()->assertJsonPath('is_following', false);
        $this->assertDatabaseMissing('customer_follows', ['customer_id' => $customer->id]);
    }

    public function test_unfollowing_a_customer_never_followed_is_a_no_op(): void
    {
        $company = $this->approvedCompanyUser();
        $customer = User::factory()->create();

        $this->actingAs($company)
            ->deleteJson("/api/company/customers/{$customer->id}/follow")
            ->assertOk()
            ->assertJsonPath('is_following', false);
    }

    public function test_cannot_follow_an_account_that_is_not_a_customer(): void
    {
        $company = $this->approvedCompanyUser();
        $otherCompanyOwner = User::factory()->transporterCompany()->create();

        $this->actingAs($company)
            ->postJson("/api/company/customers/{$otherCompanyOwner->id}/follow")
            ->assertNotFound();
    }

    public function test_index_lists_only_this_companys_followed_customers_without_contact_details(): void
    {
        $company = $this->approvedCompanyUser();
        $otherCompany = $this->approvedCompanyUser();
        $followed = User::factory()->create(['full_name' => 'Amina Hassan', 'phone_number' => '+255712345678']);
        $notFollowedByThisCompany = User::factory()->create();

        CustomerFollow::create(['transporter_company_id' => $company->transporterCompany->id, 'customer_id' => $followed->id]);
        CustomerFollow::create([
            'transporter_company_id' => $otherCompany->transporterCompany->id,
            'customer_id' => $notFollowedByThisCompany->id,
        ]);

        $response = $this->actingAs($company)->getJson('/api/company/followed-customers');

        $response->assertOk();
        $data = $response->json('data');
        $this->assertCount(1, $data);
        $this->assertSame('Amina Hassan', $data[0]['full_name']);
        // Thin shape — never a followed customer's phone/email, contact
        // stays through the in-app Message feature.
        $this->assertArrayNotHasKey('phone_number', $data[0]);
        $this->assertArrayNotHasKey('email', $data[0]);
    }

    public function test_a_pending_company_cannot_use_the_follow_endpoints(): void
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->for($user, 'owner')->create();
        $customer = User::factory()->create();

        $this->actingAs($user)->postJson("/api/company/customers/{$customer->id}/follow")->assertForbidden();
        $this->actingAs($user)->getJson('/api/company/followed-customers')->assertForbidden();
    }
}
