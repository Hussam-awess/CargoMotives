<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\ActivityLog\Index;
use App\Livewire\Admin\Companies\Show;
use App\Models\ActivityLog;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class ActivityLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_lists_entries_and_filters_by_action(): void
    {
        $admin = User::factory()->admin()->create();
        ActivityLog::factory()->create(['action' => 'company_approved', 'actor_user_id' => User::factory()->create(['full_name' => 'Approver One'])]);
        ActivityLog::factory()->create(['action' => 'truck_rejected', 'actor_user_id' => User::factory()->create(['full_name' => 'Rejector Two'])]);

        Livewire::actingAs($admin)->test(Index::class)
            ->assertSee('Approver One')->assertSee('Rejector Two')
            ->set('action', 'company_approved')
            // The filter dropdown itself always lists every distinct
            // action (so "Truck Rejected" as an <option> label never
            // disappears) — the actor name only appears in a matching
            // table row, so it's the reliable signal that filtering
            // actually happened.
            ->assertSee('Approver One')->assertDontSee('Rejector Two');
    }

    public function test_a_real_verification_action_shows_up_here(): void
    {
        $admin = User::factory()->admin()->create();
        $company = TransporterCompany::factory()->create(['verification_status' => 'pending']);

        Livewire::actingAs($admin)->test(Show::class, ['company' => $company])->call('approve');

        Livewire::actingAs($admin)->test(Index::class)->assertSee('Company Approved');
    }
}
