<?php

namespace Tests\Feature\Admin;

use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminTruckReviewTest extends TestCase
{
    use RefreshDatabase;

    public function test_non_admin_cannot_access_admin_truck_endpoints(): void
    {
        $user = User::factory()->create();
        $truck = Truck::factory()->create();

        $this->actingAs($user)->getJson('/api/admin/trucks')->assertForbidden();
        $this->actingAs($user)->postJson("/api/admin/trucks/{$truck->id}/approve")->assertForbidden();
    }

    public function test_admin_can_list_and_filter_trucks_by_status(): void
    {
        $admin = User::factory()->admin()->create();
        Truck::factory()->count(2)->create();
        Truck::factory()->approved()->create();

        $response = $this->actingAs($admin)->getJson('/api/admin/trucks?status=approved');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    public function test_admin_can_approve_a_truck(): void
    {
        $admin = User::factory()->admin()->create();
        $truck = Truck::factory()->create();

        $this->actingAs($admin)
            ->postJson("/api/admin/trucks/{$truck->id}/approve")
            ->assertOk()
            ->assertJsonPath('data.verification_status', 'approved');
    }

    public function test_admin_can_reject_a_truck_with_a_reason(): void
    {
        $admin = User::factory()->admin()->create();
        $truck = Truck::factory()->create();

        $this->actingAs($admin)
            ->postJson("/api/admin/trucks/{$truck->id}/reject", ['reason' => 'Insurance document expired.'])
            ->assertOk()
            ->assertJsonPath('data.verification_status', 'rejected')
            ->assertJsonPath('data.verification_rejected_reason', 'Insurance document expired.');
    }

    public function test_rejecting_without_a_reason_fails_validation(): void
    {
        $admin = User::factory()->admin()->create();
        $truck = Truck::factory()->create();

        $this->actingAs($admin)
            ->postJson("/api/admin/trucks/{$truck->id}/reject", [])
            ->assertUnprocessable();
    }
}
