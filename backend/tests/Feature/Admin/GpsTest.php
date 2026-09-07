<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Gps\Index;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class GpsTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_lists_connected_and_signal_lost_trucks_separately(): void
    {
        $admin = User::factory()->admin()->create();
        Truck::factory()->create([
            'registration_number' => 'T 111 LIVE', 'gps_status' => 'connected',
            'last_known_lat' => -6.8, 'last_known_lng' => 39.28, 'last_known_at' => now(),
        ]);
        Truck::factory()->create(['registration_number' => 'T 222 LOST', 'gps_status' => 'signal_lost', 'last_known_at' => now()->subHour()]);
        Truck::factory()->create(['registration_number' => 'T 333 OFF', 'gps_status' => 'not_connected']);

        Livewire::actingAs($admin)->test(Index::class)
            ->assertSee('T 111 LIVE')->assertSee('T 222 LOST')->assertDontSee('T 333 OFF');
    }
}
