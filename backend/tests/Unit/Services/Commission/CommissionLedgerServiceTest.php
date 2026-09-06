<?php

namespace Tests\Unit\Services\Commission;

use App\Models\Job;
use App\Models\Payment;
use App\Models\PlatformSetting;
use App\Models\TransporterCompany;
use App\Models\User;
use App\Services\Commission\CommissionLedgerService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The single place transporter_companies.outstanding_balance/
 * commission_standing and commission_ledger are ever written (Backend
 * Schema business rule §7, TRD §6).
 */
class CommissionLedgerServiceTest extends TestCase
{
    use RefreshDatabase;

    private function service(): CommissionLedgerService
    {
        return $this->app->make(CommissionLedgerService::class);
    }

    public function test_charging_a_completed_job_adds_the_configured_rate_to_the_balance(): void
    {
        PlatformSetting::create(['key' => 'commission_rate_default', 'value' => '30']);

        $company = TransporterCompany::factory()->create(['outstanding_balance' => 0]);
        $job = Job::factory()->create(['assigned_company_id' => $company->id, 'agreed_price' => 100000]);

        $entry = $this->service()->chargeForCompletedJob($job);

        $this->assertSame('charge', $entry->entry_type);
        $this->assertEquals(30000, $entry->amount);
        $this->assertEquals(30000, $entry->balance_after);
        $this->assertEquals(30000, $company->fresh()->outstanding_balance);
        $this->assertSame($job->id, $entry->related_job_id);
    }

    public function test_charging_past_the_hold_threshold_flips_the_company_on_hold(): void
    {
        PlatformSetting::create(['key' => 'commission_rate_default', 'value' => '30']);
        PlatformSetting::create(['key' => 'commission_hold_threshold', 'value' => '50000']);

        $company = TransporterCompany::factory()->create(['outstanding_balance' => 40000, 'commission_standing' => 'good_standing']);
        $job = Job::factory()->create(['assigned_company_id' => $company->id, 'agreed_price' => 100000]);

        $this->service()->chargeForCompletedJob($job);

        // 40000 + 30000 = 70000, >= 50000 threshold.
        $this->assertSame('on_hold', $company->fresh()->commission_standing);
    }

    public function test_a_payment_reduces_the_balance_and_lifts_a_hold(): void
    {
        PlatformSetting::create(['key' => 'commission_hold_threshold', 'value' => '50000']);

        $owner = User::factory()->create();
        $company = TransporterCompany::factory()->for($owner, 'owner')->create([
            'outstanding_balance' => 70000,
            'commission_standing' => 'on_hold',
        ]);
        $payment = Payment::factory()->succeeded()->create(['user_id' => $owner->id, 'amount' => 30000]);

        $entry = $this->service()->applyPayment($payment);

        $this->assertSame('payment', $entry->entry_type);
        $this->assertEquals(30000, $entry->amount);
        $this->assertEquals(40000, $entry->balance_after);
        $this->assertEquals(40000, $company->fresh()->outstanding_balance);
        // 40000 < 50000 threshold — hold lifted.
        $this->assertSame('good_standing', $company->fresh()->commission_standing);
        $this->assertSame($payment->id, $entry->payment_id);
    }

    public function test_a_payment_larger_than_the_balance_clamps_at_zero_rather_than_going_negative(): void
    {
        $owner = User::factory()->create();
        $company = TransporterCompany::factory()->for($owner, 'owner')->create(['outstanding_balance' => 10000]);
        $payment = Payment::factory()->succeeded()->create(['user_id' => $owner->id, 'amount' => 25000]);

        $this->service()->applyPayment($payment);

        $this->assertEquals(0, $company->fresh()->outstanding_balance);
    }
}
