<?php

namespace Tests\Feature\Company;

use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class TruckTest extends TestCase
{
    use RefreshDatabase;

    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'registration_number' => 'T 123 ABC',
            'make_model' => 'Isuzu FRR',
            'vehicle_type' => 'Flatbed',
            'capacity_tons' => 10.5,
            'photos' => [UploadedFile::fake()->create('photo1.jpg', 100, 'image/jpeg')],
            'registration_card' => UploadedFile::fake()->create('reg.pdf', 100, 'application/pdf'),
            'insurance' => UploadedFile::fake()->create('insurance.pdf', 100, 'application/pdf'),
        ], $overrides);
    }

    private function approvedCompanyUser(): User
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        return $user;
    }

    public function test_an_approved_company_can_register_a_truck(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();

        $response = $this->actingAs($user)->postJson('/api/company/trucks', $this->validPayload());

        // Regression: Eloquent's create() doesn't reflect DB-level column
        // defaults on the in-memory model it returns unless the model also
        // declares them (Truck::$attributes) — these three were null in
        // the API response before that fix, despite the DB row being
        // correct. Caught via live verification against the real stack,
        // not by this test originally — asserted here now so it can't
        // regress silently.
        $response->assertCreated()
            ->assertJsonPath('data.verification_status', 'pending')
            ->assertJsonPath('data.gps_status', 'not_connected')
            ->assertJsonPath('data.current_status', 'idle')
            ->assertJsonPath('data.is_active', true);
        $this->assertDatabaseHas('trucks', [
            'transporter_company_id' => $user->transporterCompany->id,
            'registration_number' => 'T 123 ABC',
        ]);
    }

    public function test_an_unapproved_company_cannot_register_a_truck(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->for($user, 'owner')->create(); // still pending

        $this->actingAs($user)->postJson('/api/company/trucks', $this->validPayload())->assertForbidden();
    }

    public function test_a_company_with_no_verification_at_all_cannot_register_a_truck(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $this->actingAs($user)->postJson('/api/company/trucks', $this->validPayload())->assertForbidden();
    }

    public function test_a_customer_cannot_register_a_truck(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/company/trucks', $this->validPayload())->assertForbidden();
    }

    public function test_photo_urls_and_document_urls_are_signed(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();

        $response = $this->actingAs($user)->postJson('/api/company/trucks', $this->validPayload());

        $response->assertCreated();
        $this->assertStringContainsString('signature=', $response->json('data.photo_urls.0'));
        $this->assertStringContainsString('signature=', $response->json('data.registration_card_url'));
        $this->assertStringContainsString('signature=', $response->json('data.insurance_url'));
        $this->assertNull($response->json('data.roadworthiness_permit_url'));
    }

    public function test_a_company_can_list_only_its_own_trucks(): void
    {
        $userA = $this->approvedCompanyUser();
        $userB = $this->approvedCompanyUser();
        Truck::factory()->for($userA->transporterCompany, 'company')->create();
        Truck::factory()->for($userB->transporterCompany, 'company')->create();

        $response = $this->actingAs($userA)->getJson('/api/company/trucks');

        $response->assertOk();
        $this->assertCount(1, $response->json('data'));
    }

    public function test_a_company_cannot_view_another_companys_truck(): void
    {
        $userA = $this->approvedCompanyUser();
        $userB = $this->approvedCompanyUser();
        $truck = Truck::factory()->for($userB->transporterCompany, 'company')->create();

        $this->actingAs($userA)->getJson("/api/company/trucks/{$truck->id}")->assertNotFound();
    }

    public function test_a_rejected_truck_can_be_resubmitted(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->rejected()->for($user->transporterCompany, 'company')->create();

        $response = $this->actingAs($user)->postJson(
            "/api/company/trucks/{$truck->id}",
            $this->validPayload(['make_model' => 'Corrected Model'])
        );

        $response->assertOk()
            ->assertJsonPath('data.verification_status', 'pending')
            ->assertJsonPath('data.make_model', 'Corrected Model');
        $this->assertNull($truck->fresh()->verification_rejected_reason);
    }

    public function test_an_approved_truck_cannot_be_edited(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create();

        $this->actingAs($user)
            ->postJson("/api/company/trucks/{$truck->id}", $this->validPayload())
            ->assertUnprocessable();
    }

    public function test_at_least_one_photo_is_required(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();

        $this->actingAs($user)
            ->postJson('/api/company/trucks', $this->validPayload(['photos' => []]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('photos');
    }
}
