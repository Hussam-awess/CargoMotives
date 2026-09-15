<?php

namespace Tests\Feature\Console;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class NudgeInactiveUsersTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_nudges_a_user_inactive_for_over_a_week(): void
    {
        Queue::fake();

        $user = User::factory()->create(['last_active_at' => now()->subDays(10)]);

        $this->artisan('notifications:nudge-inactive-users');

        $this->assertDatabaseHas('notifications', ['user_id' => $user->id, 'type' => 're_engagement']);
        $this->assertNotNull($user->fresh()->last_inactivity_nudge_at);
    }

    public function test_it_does_not_nudge_a_recently_active_user(): void
    {
        Queue::fake();

        $user = User::factory()->create(['last_active_at' => now()->subDays(2)]);

        $this->artisan('notifications:nudge-inactive-users');

        $this->assertDatabaseMissing('notifications', ['user_id' => $user->id, 'type' => 're_engagement']);
    }

    public function test_it_does_not_re_nudge_someone_already_nudged_recently(): void
    {
        Queue::fake();

        $user = User::factory()->create([
            'last_active_at' => now()->subDays(10),
            'last_inactivity_nudge_at' => now()->subDays(2),
        ]);

        $this->artisan('notifications:nudge-inactive-users');

        $this->assertDatabaseMissing('notifications', ['user_id' => $user->id, 'type' => 're_engagement']);
    }

    public function test_it_re_nudges_after_another_full_window_has_passed(): void
    {
        Queue::fake();

        $user = User::factory()->create([
            'last_active_at' => now()->subDays(20),
            'last_inactivity_nudge_at' => now()->subDays(8),
        ]);

        $this->artisan('notifications:nudge-inactive-users');

        $this->assertDatabaseHas('notifications', ['user_id' => $user->id, 'type' => 're_engagement']);
    }

    public function test_it_never_nudges_an_admin(): void
    {
        Queue::fake();

        $admin = User::factory()->create(['account_type' => 'admin', 'last_active_at' => now()->subDays(30)]);

        $this->artisan('notifications:nudge-inactive-users');

        $this->assertDatabaseMissing('notifications', ['user_id' => $admin->id]);
    }
}
