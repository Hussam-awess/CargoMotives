<?php

namespace Tests\Feature;

use App\Models\Payment;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PaymentHistoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_customer_sees_only_their_own_payments(): void
    {
        $customer = User::factory()->create();
        $otherCustomer = User::factory()->create();
        Payment::factory()->succeeded()->create(['user_id' => $customer->id, 'purpose' => 'featured_customer', 'amount' => 5000]);
        Payment::factory()->succeeded()->create(['user_id' => $otherCustomer->id]);

        $response = $this->actingAs($customer)->getJson('/api/payments');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
        $this->assertEquals(5000.0, $response->json('data.0.amount'));
    }

    public function test_a_company_sees_only_its_own_payments(): void
    {
        $owner = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($owner, 'owner')->create();
        $otherOwner = User::factory()->create();
        Payment::factory()->succeeded()->create(['user_id' => $owner->id, 'purpose' => 'featured_company', 'amount' => 20000]);
        Payment::factory()->succeeded()->create(['user_id' => $otherOwner->id]);

        $response = $this->actingAs($owner)->getJson('/api/company/payments');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
        $this->assertEquals(20000.0, $response->json('data.0.amount'));
    }

    public function test_payments_are_returned_newest_first(): void
    {
        $customer = User::factory()->create();
        $older = Payment::factory()->succeeded()->create(['user_id' => $customer->id, 'created_at' => now()->subDays(5)]);
        $newer = Payment::factory()->succeeded()->create(['user_id' => $customer->id, 'created_at' => now()]);

        $response = $this->actingAs($customer)->getJson('/api/payments');

        $response->assertOk();
        $this->assertSame($newer->id, $response->json('data.0.id'));
        $this->assertSame($older->id, $response->json('data.1.id'));
    }
}
