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

    public function test_repeated_failed_logins_across_different_ips_still_lock_the_account(): void
    {
        User::factory()->admin('secret123')->create(['email' => 'admin@cargomotives.co.tz']);

        // A different IP on every attempt so the per-route `throttle:*`
        // limiter (keyed on email+IP) never itself trips — isolating that
        // this lockout is LoginThrottle's own identifier-only tracking.
        for ($i = 0; $i < 5; $i++) {
            $this->withServerVariables(['REMOTE_ADDR' => "10.0.0.{$i}"])
                ->postJson('/api/admin/login', [
                    'email' => 'admin@cargomotives.co.tz',
                    'password' => 'wrong-password',
                ])->assertUnprocessable();
        }

        // A brand-new IP would sail past the per-IP+email rate limiter, but
        // LoginThrottle keys on the email alone and still blocks it — even
        // with the real password.
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.99'])
            ->postJson('/api/admin/login', [
                'email' => 'admin@cargomotives.co.tz',
                'password' => 'secret123',
            ])->assertStatus(429);
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
