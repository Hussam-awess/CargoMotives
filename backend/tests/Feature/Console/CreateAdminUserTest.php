<?php

namespace Tests\Feature\Console;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/**
 * Regression coverage for a real bug: password_hash is deliberately not in
 * User::$fillable (security-sensitive, no request path should mass-assign
 * it), which meant the original command's User::create([...'password_hash'
 * => ...]) silently dropped it — an admin account got created with no
 * usable password and login always failed. A factory-based test wouldn't
 * catch this (factories bypass mass-assignment), which is exactly how it
 * slipped through until a live manual run of `admin:create` surfaced it.
 */
class CreateAdminUserTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_an_admin_with_a_usable_password_hash(): void
    {
        $this->artisan('admin:create', [
            'phone' => '0799000001',
            'email' => 'admin@cargomotives.co.tz',
            'password' => 'supersecret123',
        ])->assertSuccessful();

        $admin = User::where('email', 'admin@cargomotives.co.tz')->first();

        $this->assertNotNull($admin);
        $this->assertSame('admin', $admin->account_type);
        $this->assertNotEmpty($admin->password_hash);
        $this->assertTrue(Hash::check('supersecret123', $admin->password_hash));
    }

    public function test_the_created_admin_can_actually_log_in_via_the_api(): void
    {
        $this->artisan('admin:create', [
            'phone' => '0799000001',
            'email' => 'admin@cargomotives.co.tz',
            'password' => 'supersecret123',
        ]);

        $this->postJson('/api/admin/login', [
            'email' => 'admin@cargomotives.co.tz',
            'password' => 'supersecret123',
        ])->assertOk()->assertJsonStructure(['token']);
    }

    public function test_it_rejects_a_duplicate_phone_or_email(): void
    {
        User::factory()->admin()->create(['phone_number' => '+255799000001']);

        $this->artisan('admin:create', [
            'phone' => '0799000001',
            'email' => 'someone-else@cargomotives.co.tz',
            'password' => 'supersecret123',
        ])->assertFailed();
    }
}
