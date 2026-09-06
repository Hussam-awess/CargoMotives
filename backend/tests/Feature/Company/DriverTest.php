<?php

namespace Tests\Feature\Company;

use App\Models\Driver;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class DriverTest extends TestCase
{
    use RefreshDatabase;

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    public function test_an_approved_company_can_add_a_driver(): void
    {
        $user = $this->approvedCompanyUser();

        $response = $this->actingAs($user)->postJson('/api/company/drivers', [
            'full_name' => 'Juma Hassan',
            'phone_number' => '0712345678',
        ]);

        // is_active regression — see Truck::$attributes / User::$attributes
        // docblocks for why a fresh create() needs this declared on the model.
        $response->assertCreated()
            ->assertJsonPath('data.full_name', 'Juma Hassan')
            ->assertJsonPath('data.phone_number', '+255712345678')
            ->assertJsonPath('data.is_active', true);
    }

    public function test_an_unapproved_company_cannot_add_a_driver(): void
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->for($user, 'owner')->create();

        $this->actingAs($user)
            ->postJson('/api/company/drivers', ['full_name' => 'Juma', 'phone_number' => '0712345678'])
            ->assertForbidden();
    }

    public function test_a_driver_can_have_an_optional_license_photo(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();

        $response = $this->actingAs($user)->post('/api/company/drivers', [
            'full_name' => 'Juma Hassan',
            'phone_number' => '0712345678',
            'license_number' => 'DL-12345',
            'license_photo' => UploadedFile::fake()->create('license.jpg', 100, 'image/jpeg'),
        ]);

        $response->assertCreated();
        $this->assertStringContainsString('signature=', $response->json('data.photo_url'));
    }

    public function test_an_invalid_phone_number_is_rejected(): void
    {
        $user = $this->approvedCompanyUser();

        $this->actingAs($user)
            ->postJson('/api/company/drivers', ['full_name' => 'Juma', 'phone_number' => '123'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('phone_number');
    }

    public function test_a_company_can_only_update_its_own_driver(): void
    {
        $userA = $this->approvedCompanyUser();
        $userB = $this->approvedCompanyUser();
        $driver = Driver::factory()->for($userB->transporterCompany, 'company')->create();

        $this->actingAs($userA)
            ->postJson("/api/company/drivers/{$driver->id}", ['full_name' => 'Hacked', 'phone_number' => '0712345678'])
            ->assertNotFound();
    }

    public function test_a_company_can_update_its_driver(): void
    {
        $user = $this->approvedCompanyUser();
        $driver = Driver::factory()->for($user->transporterCompany, 'company')->create();

        $response = $this->actingAs($user)->postJson("/api/company/drivers/{$driver->id}", [
            'full_name' => 'Updated Name',
            'phone_number' => '0712345678',
        ]);

        $response->assertOk()->assertJsonPath('data.full_name', 'Updated Name');
    }

    public function test_a_company_can_list_only_its_own_drivers(): void
    {
        $userA = $this->approvedCompanyUser();
        $userB = $this->approvedCompanyUser();
        Driver::factory()->for($userA->transporterCompany, 'company')->create();
        Driver::factory()->for($userB->transporterCompany, 'company')->create();

        $response = $this->actingAs($userA)->getJson('/api/company/drivers');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }
}
