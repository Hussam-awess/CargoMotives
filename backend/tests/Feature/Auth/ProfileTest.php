<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_can_complete_their_profile(): void
    {
        $user = User::factory()->create(['full_name' => null]);

        $response = $this->actingAs($user)->postJson('/api/auth/profile', [
            'full_name' => 'Asha Mwinyi',
        ]);

        $response->assertOk()->assertJsonPath('data.full_name', 'Asha Mwinyi');
        $this->assertSame('Asha Mwinyi', $user->fresh()->full_name);
    }

    public function test_transporter_company_cannot_use_the_customer_profile_endpoint(): void
    {
        $user = User::factory()->transporterCompany()->create();

        $this->actingAs($user)
            ->postJson('/api/auth/profile', ['full_name' => 'Someone'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('account_type');
    }

    public function test_profile_endpoint_requires_authentication(): void
    {
        $this->postJson('/api/auth/profile', ['full_name' => 'Someone'])->assertUnauthorized();
    }

    /**
     * Regression test: postJson()/getJson() send `Accept: application/json`
     * automatically, which hides a real bug — Laravel's default
     * unauthenticated-guest handling tries to redirect to a 'login' route
     * (assuming a server-rendered app) for any request that DOESN'T send
     * that header, and this API has no such route. Found by manually
     * curling the endpoint without an Accept header, which 500'd instead
     * of 401'ing. Fixed via redirectGuestsTo(null) in bootstrap/app.php.
     */
    public function test_unauthenticated_request_without_accept_header_still_gets_json_401(): void
    {
        $this->call('POST', '/api/auth/profile', ['full_name' => 'Someone'])
            ->assertUnauthorized()
            ->assertJsonStructure(['message']);
    }

    public function test_me_endpoint_returns_the_authenticated_user(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('data.phone_number', $user->phone_number);
    }

    public function test_logout_revokes_the_current_token(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/auth/logout')
            ->assertOk();

        // Sanctum's guard (a RequestGuard) memoizes the resolved user for
        // its own lifetime, and that guard instance is otherwise reused
        // across multiple simulated requests within one test — unlike real
        // traffic, where a fresh process means a fresh guard every request.
        // Without forgetting it here, this second call would still see the
        // *first* request's (pre-logout) resolved user and wrongly pass.
        Auth::forgetGuards();

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/auth/me')
            ->assertUnauthorized();
    }
}
