<?php

namespace Tests\Feature\Admin;

use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * "Admin can approve/reject/resolve a duplicate" — this phase's stated
 * deliverable (Implementation Plan, Phase 2).
 */
class AdminCompanyReviewTest extends TestCase
{
    use RefreshDatabase;

    public function test_non_admin_cannot_access_admin_company_endpoints(): void
    {
        $user = User::factory()->create();
        $company = TransporterCompany::factory()->create();

        $this->actingAs($user)->getJson('/api/admin/companies')->assertForbidden();
        $this->actingAs($user)->postJson("/api/admin/companies/{$company->id}/approve")->assertForbidden();
    }

    public function test_admin_can_list_and_filter_companies_by_status(): void
    {
        $admin = User::factory()->admin()->create();
        TransporterCompany::factory()->count(2)->create();
        TransporterCompany::factory()->flaggedDuplicate()->create();

        $response = $this->actingAs($admin)->getJson('/api/admin/companies?status=flagged_duplicate');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    public function test_admin_can_approve_a_company(): void
    {
        $admin = User::factory()->admin()->create();
        $company = TransporterCompany::factory()->create();

        $response = $this->actingAs($admin)->postJson("/api/admin/companies/{$company->id}/approve");

        $response->assertOk()->assertJsonPath('data.verification_status', 'approved');
        $this->assertNotNull($company->fresh()->verified_at);
    }

    public function test_admin_can_reject_a_company_with_a_reason(): void
    {
        $admin = User::factory()->admin()->create();
        $company = TransporterCompany::factory()->create();

        $response = $this->actingAs($admin)->postJson("/api/admin/companies/{$company->id}/reject", [
            'reason' => 'Business license photo is unreadable.',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.verification_status', 'rejected')
            ->assertJsonPath('data.verification_rejected_reason', 'Business license photo is unreadable.');
    }

    public function test_rejecting_without_a_reason_fails_validation(): void
    {
        $admin = User::factory()->admin()->create();
        $company = TransporterCompany::factory()->create();

        $this->actingAs($admin)
            ->postJson("/api/admin/companies/{$company->id}/reject", [])
            ->assertUnprocessable();
    }

    public function test_flagged_duplicate_detail_includes_the_conflicting_company(): void
    {
        $admin = User::factory()->admin()->create();
        $original = TransporterCompany::factory()->create(['registration_number' => 'REG-999']);
        $flagged = TransporterCompany::factory()->flaggedDuplicate()->create(['registration_number' => 'REG-999']);

        $response = $this->actingAs($admin)->getJson("/api/admin/companies/{$flagged->id}");

        $response->assertOk()->assertJsonPath('conflicting_company.id', $original->id);
    }
}
