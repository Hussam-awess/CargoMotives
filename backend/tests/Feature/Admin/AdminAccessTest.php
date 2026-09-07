<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Auth\Login;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

/**
 * The session-guard gate every Admin route sits behind (TRD §8): a guest
 * lands on the real login page (bootstrap/app.php's redirectGuestsTo),
 * and only account_type='admin' gets past EnsureAccountType.
 */
class AdminAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_guest_is_redirected_to_the_admin_login_page(): void
    {
        $this->get('/admin')->assertRedirect(route('admin.login'));
    }

    public function test_a_non_admin_session_user_is_forbidden(): void
    {
        $customer = User::factory()->create();

        $this->actingAs($customer)->get('/admin')->assertForbidden();
    }

    public function test_an_admin_can_reach_the_dashboard(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin)->get('/admin')->assertOk();
    }

    public function test_login_succeeds_with_correct_credentials_and_redirects_to_dashboard(): void
    {
        $admin = User::factory()->admin('secret123')->create();

        Livewire::test(Login::class)
            ->set('email', $admin->email)
            ->set('password', 'secret123')
            ->call('login')
            ->assertRedirect(route('admin.dashboard'));

        $this->assertAuthenticatedAs($admin);
    }

    public function test_login_fails_with_the_wrong_password(): void
    {
        $admin = User::factory()->admin('secret123')->create();

        Livewire::test(Login::class)
            ->set('email', $admin->email)
            ->set('password', 'wrong-password')
            ->call('login')
            ->assertHasErrors('email');

        $this->assertGuest();
    }

    public function test_a_customer_account_cannot_log_in_through_the_admin_form(): void
    {
        $customer = User::factory()->withPassword('secret123')->create();

        Livewire::test(Login::class)
            ->set('email', $customer->email)
            ->set('password', 'secret123')
            ->call('login')
            ->assertHasErrors('email');

        $this->assertGuest();
    }

    public function test_logout_ends_the_session(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin)->post(route('admin.logout'))->assertRedirect(route('admin.login'));
        $this->assertGuest();
    }
}
