<?php

namespace Tests\Feature\Company;

use App\Models\CommissionLedger;
use App\Models\PlatformSetting;
use App\Models\TransporterCompany;
use App\Models\User;
use App\Services\MobileMoney\MobileMoneyChargeResult;
use App\Services\MobileMoney\MobileMoneyGateway;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CommissionTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(array $companyAttributes = []): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create($companyAttributes);

        return $user;
    }

    public function test_summary_reports_balance_standing_and_threshold(): void
    {
        PlatformSetting::create(['key' => 'commission_hold_threshold', 'value' => '500000']);
        $company = $this->approvedCompanyUser(['outstanding_balance' => 75000, 'commission_standing' => 'good_standing']);

        $this->actingAs($company)
            ->getJson('/api/company/commission/summary')
            ->assertOk()
            ->assertJson(['outstanding_balance' => 75000.0, 'commission_standing' => 'good_standing', 'hold_threshold' => 500000.0]);
    }

    public function test_ledger_lists_only_this_companys_entries(): void
    {
        $company = $this->approvedCompanyUser();
        $companyId = $company->transporterCompany->id;
        CommissionLedger::factory()->create(['transporter_company_id' => $companyId]);
        CommissionLedger::factory()->create(); // another company's

        $response = $this->actingAs($company)->getJson('/api/company/commission/ledger');

        $response->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_initiating_a_payment_pushes_a_charge_and_returns_pending_confirmation(): void
    {
        $company = $this->approvedCompanyUser(['outstanding_balance' => 50000]);

        $this->mock(MobileMoneyGateway::class, function ($mock) {
            $mock->shouldReceive('initiateCharge')
                ->once()
                ->andReturn(MobileMoneyChargeResult::initiated('SEL-REF-1', ['result' => 'SUCCESS']));
        });

        $response = $this->actingAs($company)->postJson('/api/company/commission/payments', [
            'amount' => 20000,
            'mobile_money_provider' => 'mpesa',
            'phone_number' => '0712345678',
        ]);

        $response->assertCreated()->assertJsonPath('data.status', 'pending_confirmation');
        $this->assertDatabaseHas('payments', ['status' => 'pending_confirmation', 'amount' => 20000]);
        // Not credited yet — only the webhook confirming success does that.
        $this->assertEquals(50000, $company->transporterCompany->fresh()->outstanding_balance);
    }

    public function test_a_gateway_failure_marks_the_payment_failed_without_throwing(): void
    {
        $company = $this->approvedCompanyUser(['outstanding_balance' => 50000]);

        $this->mock(MobileMoneyGateway::class, function ($mock) {
            $mock->shouldReceive('initiateCharge')
                ->once()
                ->andReturn(MobileMoneyChargeResult::failed('Insufficient funds.'));
        });

        $this->actingAs($company)->postJson('/api/company/commission/payments', [
            'amount' => 20000,
            'mobile_money_provider' => 'mpesa',
            'phone_number' => '0712345678',
        ])->assertCreated()->assertJsonPath('data.status', 'failed');
    }

    public function test_cannot_pay_more_than_the_outstanding_balance(): void
    {
        $company = $this->approvedCompanyUser(['outstanding_balance' => 10000]);

        $this->actingAs($company)
            ->postJson('/api/company/commission/payments', [
                'amount' => 20000,
                'mobile_money_provider' => 'mpesa',
                'phone_number' => '0712345678',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('amount');
    }

    public function test_cannot_pay_anything_when_the_balance_is_zero(): void
    {
        $company = $this->approvedCompanyUser(['outstanding_balance' => 0]);

        $this->actingAs($company)
            ->postJson('/api/company/commission/payments', [
                'amount' => 1,
                'mobile_money_provider' => 'mpesa',
                'phone_number' => '0712345678',
            ])
            ->assertUnprocessable();
    }
}
