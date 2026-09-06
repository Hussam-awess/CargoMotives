<?php

namespace Tests\Feature\Customer;

use App\Models\PlatformSetting;
use App\Models\User;
use App\Services\MobileMoney\MobileMoneyChargeResult;
use App\Services\MobileMoney\MobileMoneyGateway;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FeaturedTest extends TestCase
{
    use RefreshDatabase;

    public function test_status_reports_price_and_current_state(): void
    {
        PlatformSetting::create(['key' => 'customer_featured_price', 'value' => '20000']);
        $customer = User::factory()->create(['is_featured' => false]);

        $this->actingAs($customer)
            ->getJson('/api/featured/status')
            ->assertOk()
            ->assertJson(['is_featured' => false, 'price' => 20000.0]);
    }

    public function test_purchasing_pushes_a_charge_but_does_not_activate_immediately(): void
    {
        $customer = User::factory()->create(['is_featured' => false]);

        $this->mock(MobileMoneyGateway::class, function ($mock) {
            $mock->shouldReceive('initiateCharge')->once()->andReturn(MobileMoneyChargeResult::initiated('ref-1'));
        });

        $this->actingAs($customer)
            ->postJson('/api/featured/purchase', ['mobile_money_provider' => 'mpesa', 'phone_number' => '0712345678'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending_confirmation');

        $this->assertFalse((bool) $customer->fresh()->is_featured);
        $this->assertDatabaseHas('payments', ['purpose' => 'featured_customer', 'status' => 'pending_confirmation']);
    }

    public function test_a_company_cannot_use_the_customer_featured_endpoint(): void
    {
        $company = User::factory()->transporterCompany()->create();

        $this->actingAs($company)->getJson('/api/featured/status')->assertForbidden();
    }
}
