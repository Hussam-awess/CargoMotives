<?php

namespace Tests\Feature\Auth;

use App\Models\Bid;
use App\Models\DeviceToken;
use App\Models\Driver;
use App\Models\GpsConnection;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_customer_can_delete_their_account_and_their_personal_data_is_erased(): void
    {
        $user = User::factory()->withPassword('secret123')->create(['full_name' => 'Amina Hassan']);
        $token = $user->createToken('Phone');
        DeviceToken::factory()->create(['user_id' => $user->id]);
        $originalPhone = $user->phone_number;

        $this->withToken($token->plainTextToken)
            ->deleteJson('/api/auth/account', ['current_password' => 'secret123'])
            ->assertOk();

        $deleted = User::withTrashed()->find($user->id);
        $this->assertTrue($deleted->trashed());
        $this->assertNull($deleted->full_name);
        $this->assertNull($deleted->email);
        $this->assertNull($deleted->password_hash);
        $this->assertNotSame($originalPhone, $deleted->phone_number);
        $this->assertSame(0, PersonalAccessToken::where('tokenable_id', $user->id)->count());
        $this->assertSame(0, DeviceToken::where('user_id', $user->id)->count());
    }

    public function test_the_freed_phone_number_can_sign_up_again(): void
    {
        $user = User::factory()->withPassword('secret123')->create();
        $phone = $user->phone_number;

        $this->actingAs($user)->deleteJson('/api/auth/account', ['current_password' => 'secret123'])->assertOk();

        $this->assertFalse(User::withTrashed()->where('phone_number', $phone)->exists());
    }

    public function test_a_deleted_customer_can_no_longer_log_in(): void
    {
        $user = User::factory()->withPassword('secret123')->create();
        $email = $user->email;

        $this->actingAs($user)->deleteJson('/api/auth/account', ['current_password' => 'secret123'])->assertOk();

        $this->postJson('/api/auth/customer/login', ['email' => $email, 'password' => 'secret123'])
            ->assertUnprocessable();
    }

    public function test_the_wrong_password_deletes_nothing(): void
    {
        $user = User::factory()->withPassword('secret123')->create();

        $this->actingAs($user)
            ->deleteJson('/api/auth/account', ['current_password' => 'wrong'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('current_password');

        $this->assertFalse($user->fresh()->trashed());
    }

    public function test_a_customer_with_a_job_in_progress_cannot_delete_their_account(): void
    {
        $user = User::factory()->withPassword('secret123')->create();
        Job::factory()->assigned()->create(['customer_id' => $user->id]);

        $this->actingAs($user)
            ->deleteJson('/api/auth/account', ['current_password' => 'secret123'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('account');

        $this->assertFalse($user->fresh()->trashed());
    }

    public function test_finished_jobs_do_not_block_deletion_and_are_kept_for_the_record(): void
    {
        $user = User::factory()->withPassword('secret123')->create();
        $job = Job::factory()->create(['customer_id' => $user->id, 'status' => 'completed']);

        $this->actingAs($user)->deleteJson('/api/auth/account', ['current_password' => 'secret123'])->assertOk();

        $this->assertNotNull(Job::find($job->id));
    }

    public function test_a_company_with_a_pending_bid_cannot_delete_its_account(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $owner = $company->owner;
        $owner->forceFill(['password_hash' => bcrypt('secret123')])->save();
        Bid::factory()->create(['transporter_company_id' => $company->id, 'status' => 'pending']);

        $this->actingAs($owner)
            ->deleteJson('/api/auth/account', ['current_password' => 'secret123'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('account');
    }

    public function test_deleting_a_company_account_erases_representative_driver_and_gps_credentials(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $owner = $company->owner;
        $owner->forceFill(['password_hash' => bcrypt('secret123')])->save();
        $driver = Driver::factory()->create(['transporter_company_id' => $company->id]);
        $connection = GpsConnection::factory()->create(['transporter_company_id' => $company->id]);

        $this->actingAs($owner)->deleteJson('/api/auth/account', ['current_password' => 'secret123'])->assertOk();

        $company->refresh();
        $this->assertSame('[deleted]', $company->rep_full_name);
        $this->assertSame('[deleted]', $company->rep_national_id_number);
        $this->assertNull($company->documents);
        $this->assertSame('[deleted]', $driver->fresh()->phone_number);
        $this->assertSame('', $connection->fresh()->access_token);
        $this->assertSame('disconnected', $connection->fresh()->status);
        $this->assertTrue($owner->fresh()?->trashed() ?? User::withTrashed()->find($owner->id)->trashed());
    }

    public function test_a_deleted_companys_public_profile_is_gone(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $owner = $company->owner;
        $owner->forceFill(['password_hash' => bcrypt('secret123')])->save();

        $this->actingAs($owner)->deleteJson('/api/auth/account', ['current_password' => 'secret123'])->assertOk();

        $viewer = User::factory()->create();
        $this->actingAs($viewer)->getJson("/api/profiles/companies/{$company->id}")->assertNotFound();
    }
}
