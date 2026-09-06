<?php

namespace Tests\Unit\Services\Featured;

use App\Models\Payment;
use App\Models\PlatformSetting;
use App\Models\TransporterCompany;
use App\Models\User;
use App\Services\Featured\FeaturedTierService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use InvalidArgumentException;
use Tests\TestCase;

class FeaturedTierServiceTest extends TestCase
{
    use RefreshDatabase;

    private function service(): FeaturedTierService
    {
        return $this->app->make(FeaturedTierService::class);
    }

    public function test_a_featured_company_purchase_activates_the_company(): void
    {
        PlatformSetting::create(['key' => 'featured_duration_days', 'value' => '30']);
        $owner = User::factory()->create();
        $company = TransporterCompany::factory()->for($owner, 'owner')->create(['is_featured' => false]);
        $payment = Payment::factory()->succeeded()->create(['user_id' => $owner->id, 'purpose' => 'featured_company']);

        $this->service()->activateFromPayment($payment);

        $company->refresh();
        $this->assertTrue((bool) $company->is_featured);
        $this->assertNotNull($company->featured_until);
        $this->assertTrue($company->featured_until->isAfter(now()->addDays(29)));
    }

    public function test_a_featured_customer_purchase_activates_the_customer(): void
    {
        PlatformSetting::create(['key' => 'featured_duration_days', 'value' => '14']);
        $customer = User::factory()->create(['is_featured' => false]);
        $payment = Payment::factory()->succeeded()->create(['user_id' => $customer->id, 'purpose' => 'featured_customer']);

        $this->service()->activateFromPayment($payment);

        $customer->refresh();
        $this->assertTrue((bool) $customer->is_featured);
        $this->assertTrue($customer->featured_until->isAfter(now()->addDays(13)));
    }

    public function test_a_non_featured_purpose_is_rejected(): void
    {
        $owner = User::factory()->create();
        $payment = Payment::factory()->succeeded()->create(['user_id' => $owner->id, 'purpose' => 'commission_payment']);

        $this->expectException(InvalidArgumentException::class);

        $this->service()->activateFromPayment($payment);
    }
}
