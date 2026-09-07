<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Commission\Index;
use App\Livewire\Admin\Commission\Show;
use App\Models\CommissionLedger;
use App\Models\Payment;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class CommissionTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_index_filters_by_commission_standing(): void
    {
        $admin = User::factory()->admin()->create();
        TransporterCompany::factory()->approved()->create(['company_name' => 'Good Co', 'commission_standing' => 'good_standing']);
        TransporterCompany::factory()->approved()->create(['company_name' => 'Held Co', 'commission_standing' => 'on_hold', 'outstanding_balance' => 600000]);

        Livewire::actingAs($admin)->test(Index::class)
            ->assertSee('Good Co')->assertSee('Held Co')
            ->set('standing', 'on_hold')
            ->assertDontSee('Good Co')->assertSee('Held Co');
    }

    public function test_the_show_page_lists_ledger_entries_and_payment_attempts(): void
    {
        $admin = User::factory()->admin()->create();
        $owner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->create(['owner_user_id' => $owner->id]);
        CommissionLedger::factory()->create(['transporter_company_id' => $company->id, 'entry_type' => 'charge', 'amount' => 30000]);
        Payment::factory()->create(['user_id' => $owner->id, 'purpose' => 'commission_payment', 'status' => 'succeeded']);

        Livewire::actingAs($admin)->test(Show::class, ['company' => $company])
            ->assertSee('30,000')
            ->assertSee('Succeeded');
    }
}
