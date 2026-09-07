<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Trucks\Index;
use App\Livewire\Admin\Trucks\Show;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class TrucksTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_index_filters_by_verification_status(): void
    {
        $admin = User::factory()->admin()->create();
        Truck::factory()->create(['registration_number' => 'T 111 AAA', 'verification_status' => 'pending']);
        Truck::factory()->approved()->create(['registration_number' => 'T 222 BBB']);

        Livewire::actingAs($admin)->test(Index::class)
            ->assertSee('T 111 AAA')->assertSee('T 222 BBB')
            ->set('status', 'approved')
            ->assertDontSee('T 111 AAA')->assertSee('T 222 BBB');
    }

    public function test_admin_can_approve_a_pending_truck(): void
    {
        $admin = User::factory()->admin()->create();
        $truck = Truck::factory()->create(['verification_status' => 'pending']);

        Livewire::actingAs($admin)->test(Show::class, ['truck' => $truck])->call('approve');

        $truck->refresh();
        $this->assertSame('approved', $truck->verification_status);
        $this->assertDatabaseHas('activity_logs', [
            'action' => 'truck_approved', 'subject_type' => Truck::class, 'subject_id' => $truck->id,
        ]);
    }

    public function test_admin_can_reject_a_pending_truck_with_a_reason(): void
    {
        $admin = User::factory()->admin()->create();
        $truck = Truck::factory()->create(['verification_status' => 'pending']);

        Livewire::actingAs($admin)->test(Show::class, ['truck' => $truck])
            ->set('rejectReason', 'Insurance document expired.')
            ->call('reject');

        $truck->refresh();
        $this->assertSame('rejected', $truck->verification_status);
        $this->assertSame('Insurance document expired.', $truck->verification_rejected_reason);
    }
}
