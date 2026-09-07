<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Settings\Edit;
use App\Models\User;
use App\Services\Settings\PlatformSettings;
use Database\Seeders\PlatformSettingsSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class SettingsTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_loads_existing_values(): void
    {
        $admin = User::factory()->admin()->create();
        $this->seed(PlatformSettingsSeeder::class);

        Livewire::actingAs($admin)->test(Edit::class)
            ->assertSet('values.commission_rate_default', '30');
    }

    public function test_saving_updates_the_database_and_records_the_admin(): void
    {
        $admin = User::factory()->admin()->create();
        // The real form edits all seeded keys at once (TRD §8's "single
        // basic form," not a per-key editor) — every key is
        // required|numeric, so a realistic test seeds all of them, not
        // just the one under test.
        $this->seed(PlatformSettingsSeeder::class);

        Livewire::actingAs($admin)->test(Edit::class)
            ->set('values.commission_rate_default', '25')
            ->call('save');

        $this->assertDatabaseHas('platform_settings', [
            'key' => 'commission_rate_default', 'value' => '25', 'updated_by_admin_id' => $admin->id,
        ]);
    }

    public function test_saving_busts_the_cached_read_so_the_new_value_takes_effect_immediately(): void
    {
        $admin = User::factory()->admin()->create();
        $this->seed(PlatformSettingsSeeder::class);
        // Prime the cache the same way a real request would.
        app(PlatformSettings::class)->getInt('commission_rate_default', 30);

        Livewire::actingAs($admin)->test(Edit::class)
            ->set('values.commission_rate_default', '25')
            ->call('save');

        $this->assertSame(25, app(PlatformSettings::class)->getInt('commission_rate_default', 30));
    }

    public function test_a_non_numeric_value_fails_validation(): void
    {
        $admin = User::factory()->admin()->create();
        $this->seed(PlatformSettingsSeeder::class);

        Livewire::actingAs($admin)->test(Edit::class)
            ->set('values.commission_rate_default', 'not-a-number')
            ->call('save')
            ->assertHasErrors('values.commission_rate_default');
    }
}
