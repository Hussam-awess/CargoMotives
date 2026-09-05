<?php

namespace Tests\Feature\Admin;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminAuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_login_with_correct_credentials(): void
    {
        User::factory()->admin('secret123')->create(['email' => 'admin@cargomotives.co.tz']);

        $response = $this->postJson('/api/admin/login', [
            'email' => 'admin@cargomotives.co.tz',
            'password' => 'secret123',
        ]);

        $response->assertOk()->assertJsonStructure(['token', 'user']);
    }

    public function test_login_fails_with_wrong_password(): void
    {
        User::factory()->admin('secret123')->create(['email' => 'admin@cargomotives.co.tz']);

        $this->postJson('/api/admin/login', [
            'email' => 'admin@cargomotives.co.tz',
            'password' => 'wrong',
        ])->assertUnprocessable();
    }

    public function test_non_admin_account_type_cannot_login_here_even_with_a_password_set(): void
    {
        User::factory()->withPassword('secret123')->create(['email' => 'customer@example.com']);

        $this->postJson('/api/admin/login', [
            'email' => 'customer@example.com',
            'password' => 'secret123',
        ])->assertUnprocessable();
    }
}
