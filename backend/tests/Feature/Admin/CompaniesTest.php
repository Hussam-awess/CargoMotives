<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Companies\Index;
use App\Livewire\Admin\Companies\Show;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class CompaniesTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_index_filters_by_verification_status(): void
    {
        $admin = User::factory()->admin()->create();
        TransporterCompany::factory()->create(['company_name' => 'Pending Co', 'verification_status' => 'pending']);
        TransporterCompany::factory()->approved()->create(['company_name' => 'Approved Co']);

        Livewire::actingAs($admin)->test(Index::class)
            ->assertSee('Pending Co')->assertSee('Approved Co')
            ->set('status', 'approved')
            ->assertDontSee('Pending Co')->assertSee('Approved Co');
    }

    public function test_admin_can_approve_a_pending_company(): void
    {
        $admin = User::factory()->admin()->create();
        $company = TransporterCompany::factory()->create(['verification_status' => 'pending']);

        Livewire::actingAs($admin)->test(Show::class, ['company' => $company])
            ->call('approve');

        $company->refresh();
        $this->assertSame('approved', $company->verification_status);
        $this->assertNotNull($company->verified_at);
        $this->assertDatabaseHas('activity_logs', [
            'action' => 'company_approved',
            'subject_type' => TransporterCompany::class,
            'subject_id' => $company->id,
            'actor_user_id' => $admin->id,
        ]);
    }

    public function test_admin_can_reject_a_pending_company_with_a_reason(): void
    {
        $admin = User::factory()->admin()->create();
        $company = TransporterCompany::factory()->create(['verification_status' => 'pending']);

        Livewire::actingAs($admin)->test(Show::class, ['company' => $company])
            ->set('rejectReason', 'Registration document is illegible.')
            ->call('reject');

        $company->refresh();
        $this->assertSame('rejected', $company->verification_status);
        $this->assertSame('Registration document is illegible.', $company->verification_rejected_reason);
        $this->assertDatabaseHas('activity_logs', ['action' => 'company_rejected', 'subject_id' => $company->id]);
    }

    public function test_rejecting_without_a_reason_fails_validation(): void
    {
        $admin = User::factory()->admin()->create();
        $company = TransporterCompany::factory()->create(['verification_status' => 'pending']);

        Livewire::actingAs($admin)->test(Show::class, ['company' => $company])
            ->set('rejectReason', '')
            ->call('reject')
            ->assertHasErrors('rejectReason');

        $this->assertSame('pending', $company->fresh()->verification_status);
    }

    public function test_a_flagged_duplicate_company_shows_its_conflicting_company(): void
    {
        $admin = User::factory()->admin()->create();
        $original = TransporterCompany::factory()->approved()->create([
            'registration_number' => 'REG-1', 'tin' => 'TIN-1', 'rep_national_id_number' => 'NIDA-1',
        ]);
        $duplicate = TransporterCompany::factory()->flaggedDuplicate()->create([
            'registration_number' => 'REG-1', 'tin' => 'TIN-DIFFERENT', 'rep_national_id_number' => 'NIDA-DIFFERENT',
        ]);

        Livewire::actingAs($admin)->test(Show::class, ['company' => $duplicate])
            ->assertSee($original->company_name);
    }
}
