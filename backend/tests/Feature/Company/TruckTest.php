<?php

namespace Tests\Feature\Company;

use App\Models\GpsConnection;
use App\Models\Job;
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
        // 'approved' on creation, not 'pending': truck review was removed,
        // so a registered truck is usable straight away.
        $response->assertCreated()
            ->assertJsonPath('data.verification_status', 'approved')
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

    /**
     * Truck review was removed, so editing is no longer gated on a
     * pending/rejected status — but an already-real truck (one that isn't
     * a bare GPS import awaiting its first real details) is now locked to
     * just capacity/type: registration number, make/model, and documents
     * describe a specific physical vehicle and shouldn't casually change
     * after the fact. See SubmitTruckRequest::rules()'s "locked" branch.
     */
    public function test_editing_an_already_real_truck_only_applies_capacity_and_type(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'registration_number' => 'T 111 AAA',
            'make_model' => 'Original Model',
            'vehicle_type' => 'Flatbed',
            'capacity_tons' => 10,
        ]);

        $response = $this->actingAs($user)->postJson(
            "/api/company/trucks/{$truck->id}",
            $this->validPayload([
                'registration_number' => 'T 999 ZZZ',
                'make_model' => 'Corrected Model',
                'vehicle_type' => 'Tanker',
                'capacity_tons' => 7.5,
            ])
        );

        $response->assertOk()
            ->assertJsonPath('data.verification_status', 'approved')
            ->assertJsonPath('data.capacity_tons', 7.5)
            ->assertJsonPath('data.vehicle_type', 'Tanker')
            ->assertJsonPath('data.registration_number', 'T 111 AAA')
            ->assertJsonPath('data.make_model', 'Original Model');
        $this->assertNull($truck->fresh()->verification_rejected_reason);
    }

    /**
     * The point of the edit flow: correcting a capacity (or a plate typo)
     * must not mean re-uploading the registration card and insurance.
     */
    public function test_editing_vehicle_details_keeps_the_existing_documents(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'capacity_tons' => 10,
            'documents' => [
                'photos' => ['trucks/photos/existing.jpg'],
                'registration_card' => 'trucks/documents/existing-card.pdf',
                'insurance' => 'trucks/documents/existing-insurance.pdf',
            ],
        ]);

        $response = $this->actingAs($user)->postJson("/api/company/trucks/{$truck->id}", [
            'registration_number' => $truck->registration_number,
            'make_model' => $truck->make_model,
            'vehicle_type' => $truck->vehicle_type,
            'capacity_tons' => 25.5,
        ]);

        $response->assertOk()->assertJsonPath('data.capacity_tons', 25.5);
        // assertEquals, not assertSame: the JSON column round-trips the
        // keys back in a different order, which says nothing about content.
        $this->assertEquals([
            'photos' => ['trucks/photos/existing.jpg'],
            'registration_card' => 'trucks/documents/existing-card.pdf',
            'insurance' => 'trucks/documents/existing-insurance.pdf',
        ], $truck->fresh()->documents);
    }

    /**
     * A bare GPS-imported truck (is_gps_imported still true) is still
     * completing its real details for the first time, so its documents
     * stay fully replaceable, same as any other field on that first save.
     */
    public function test_completing_a_gps_imported_trucks_details_replaces_only_the_documents_reattached(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'is_gps_imported' => true,
            'documents' => [
                'photos' => ['trucks/photos/existing.jpg'],
                'registration_card' => 'trucks/documents/existing-card.pdf',
                'insurance' => 'trucks/documents/existing-insurance.pdf',
            ],
        ]);

        $this->actingAs($user)->postJson("/api/company/trucks/{$truck->id}", [
            'registration_number' => $truck->registration_number,
            'make_model' => $truck->make_model,
            'vehicle_type' => $truck->vehicle_type,
            'capacity_tons' => 10,
            'insurance' => UploadedFile::fake()->create('new-insurance.pdf', 100, 'application/pdf'),
        ])->assertOk();

        $documents = $truck->fresh()->documents;
        $this->assertNotSame('trucks/documents/existing-insurance.pdf', $documents['insurance']);
        $this->assertSame('trucks/documents/existing-card.pdf', $documents['registration_card']);
        $this->assertSame(['trucks/photos/existing.jpg'], $documents['photos']);
    }

    /**
     * Once a truck is locked (real details already on file), even
     * attaching a new document is ignored — hasFile() doesn't care about
     * validation rules, so TruckController::save() has to explicitly skip
     * the whole document-handling block for a locked update.
     */
    public function test_editing_an_already_real_truck_ignores_a_reattached_document(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'documents' => [
                'photos' => ['trucks/photos/existing.jpg'],
                'registration_card' => 'trucks/documents/existing-card.pdf',
                'insurance' => 'trucks/documents/existing-insurance.pdf',
            ],
        ]);

        $this->actingAs($user)->postJson("/api/company/trucks/{$truck->id}", [
            'capacity_tons' => 10,
            'vehicle_type' => $truck->vehicle_type,
            'insurance' => UploadedFile::fake()->create('new-insurance.pdf', 100, 'application/pdf'),
        ])->assertOk();

        $documents = $truck->fresh()->documents;
        $this->assertSame('trucks/documents/existing-insurance.pdf', $documents['insurance']);
        $this->assertSame('trucks/documents/existing-card.pdf', $documents['registration_card']);
        $this->assertSame(['trucks/photos/existing.jpg'], $documents['photos']);
    }

    public function test_registering_a_new_truck_still_requires_its_documents(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();

        $this->actingAs($user)->postJson('/api/company/trucks', [
            'registration_number' => 'T 321 CBA',
            'make_model' => 'Isuzu',
            'vehicle_type' => 'Flatbed',
            'capacity_tons' => 10,
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['photos', 'registration_card', 'insurance']);
    }

    public function test_a_company_cannot_edit_another_companys_truck(): void
    {
        Storage::fake('local');
        $userA = $this->approvedCompanyUser();
        $userB = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($userB->transporterCompany, 'company')->create();

        $this->actingAs($userA)
            ->postJson("/api/company/trucks/{$truck->id}", $this->validPayload())
            ->assertNotFound();
    }

    public function test_a_gps_imported_truck_can_be_completed_and_the_flag_clears(): void
    {
        Storage::fake('local');
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'is_gps_imported' => true,
            'make_model' => 'Pending real details',
        ]);

        $response = $this->actingAs($user)->postJson(
            "/api/company/trucks/{$truck->id}",
            $this->validPayload(['make_model' => 'Isuzu FRR'])
        );

        $response->assertOk()
            ->assertJsonPath('data.make_model', 'Isuzu FRR')
            ->assertJsonPath('data.is_gps_imported', false)
            ->assertJsonPath('data.verification_status', 'approved');
    }

    public function test_gps_online_is_true_only_for_a_connected_truck_with_a_recent_position(): void
    {
        $user = $this->approvedCompanyUser();
        $online = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'connected',
            'last_known_at' => now()->subMinutes(2),
        ]);
        $stale = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'connected',
            'last_known_at' => now()->subMinutes(30),
        ]);
        $neverReported = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'connected',
            'last_known_at' => null,
        ]);
        $notConnected = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'not_connected',
            'last_known_at' => now(),
        ]);

        $response = $this->actingAs($user)->getJson('/api/company/trucks');

        $byId = collect($response->json('data'))->keyBy('id');
        $this->assertTrue($byId[$online->id]['gps_online']);
        $this->assertFalse($byId[$stale->id]['gps_online']);
        $this->assertFalse($byId[$neverReported->id]['gps_online']);
        $this->assertFalse($byId[$notConnected->id]['gps_online']);
    }

    public function test_gps_moving_reflects_movement_duration_not_just_the_latest_speed(): void
    {
        $user = $this->approvedCompanyUser();
        $movingNow = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'connected', 'last_known_at' => now()->subMinutes(1), 'stationary_since' => null,
        ]);
        $recentlyStopped = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'connected', 'last_known_at' => now()->subMinutes(1),
            'stationary_since' => now()->subMinutes(5),
        ]);
        $stationary15Plus = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'connected', 'last_known_at' => now()->subMinutes(1),
            'stationary_since' => now()->subMinutes(20),
        ]);
        $offline = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'connected', 'last_known_at' => now()->subMinutes(30), 'stationary_since' => null,
        ]);

        $response = $this->actingAs($user)->getJson('/api/company/trucks');

        $byId = collect($response->json('data'))->keyBy('id');
        $this->assertTrue($byId[$movingNow->id]['gps_moving']);
        $this->assertTrue($byId[$recentlyStopped->id]['gps_moving']);
        $this->assertFalse($byId[$stationary15Plus->id]['gps_moving']);
        $this->assertFalse($byId[$offline->id]['gps_moving']);
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

    public function test_an_idle_truck_can_be_removed(): void
    {
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create(['current_status' => 'idle']);

        $this->actingAs($user)
            ->deleteJson("/api/company/trucks/{$truck->id}")
            ->assertOk();

        $this->assertSoftDeleted('trucks', ['id' => $truck->id]);
    }

    public function test_a_truck_on_a_job_cannot_be_removed(): void
    {
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create(['current_status' => 'on_job']);

        $this->actingAs($user)
            ->deleteJson("/api/company/trucks/{$truck->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('truck');

        $this->assertDatabaseHas('trucks', ['id' => $truck->id, 'deleted_at' => null]);
    }

    public function test_a_gps_connected_truck_cannot_be_removed(): void
    {
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'current_status' => 'idle',
            'gps_status' => 'connected',
        ]);

        $this->actingAs($user)
            ->deleteJson("/api/company/trucks/{$truck->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('truck');

        $this->assertDatabaseHas('trucks', ['id' => $truck->id, 'deleted_at' => null]);
    }

    public function test_disconnecting_gps_allows_the_truck_to_then_be_removed(): void
    {
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'current_status' => 'idle',
            'gps_status' => 'connected',
        ]);

        $this->actingAs($user)->postJson("/api/company/trucks/{$truck->id}/disconnect-gps")->assertOk();
        $this->actingAs($user)->deleteJson("/api/company/trucks/{$truck->id}")->assertOk();

        $this->assertSoftDeleted('trucks', ['id' => $truck->id]);
    }

    /**
     * Distinct from GpsConnectionController::disconnect() (whole
     * connection): this clears gps_connection_id/gps_unit_id on just the
     * one truck, not only gps_status — PollGpsPositionsJob selects trucks
     * to poll by those IDs, so leaving them in place would mean the next
     * poll cycle keeps reporting positions for a truck that was just
     * disconnected.
     */
    public function test_disconnecting_gps_clears_the_connection_and_unit_id(): void
    {
        $user = $this->approvedCompanyUser();
        $connection = GpsConnection::factory()->create([
            'transporter_company_id' => $user->transporterCompany->id,
        ]);
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'gps_status' => 'connected',
            'gps_connection_id' => $connection->id,
            'gps_unit_id' => 'unit-42',
        ]);

        $response = $this->actingAs($user)->postJson("/api/company/trucks/{$truck->id}/disconnect-gps");

        $response->assertOk()->assertJsonPath('data.gps_status', 'not_connected');
        $fresh = $truck->fresh();
        $this->assertSame('not_connected', $fresh->gps_status);
        $this->assertNull($fresh->gps_connection_id);
        $this->assertNull($fresh->gps_unit_id);
    }

    public function test_a_company_cannot_disconnect_gps_on_another_companys_truck(): void
    {
        $user = $this->approvedCompanyUser();
        $otherTruck = Truck::factory()->approved()->create(['gps_status' => 'connected']);

        $this->actingAs($user)
            ->postJson("/api/company/trucks/{$otherTruck->id}/disconnect-gps")
            ->assertNotFound();
    }

    public function test_cannot_remove_another_companys_truck(): void
    {
        $user = $this->approvedCompanyUser();
        $otherTruck = Truck::factory()->approved()->create(['current_status' => 'idle']);

        $this->actingAs($user)
            ->deleteJson("/api/company/trucks/{$otherTruck->id}")
            ->assertNotFound();
    }

    public function test_a_removed_trucks_registration_still_shows_on_its_past_jobs(): void
    {
        $user = $this->approvedCompanyUser();
        $truck = Truck::factory()->approved()->for($user->transporterCompany, 'company')->create([
            'current_status' => 'idle',
            'registration_number' => 'T 999 XYZ',
        ]);
        $job = Job::factory()->create(['assigned_truck_id' => $truck->id, 'status' => 'completed']);

        $this->actingAs($user)->deleteJson("/api/company/trucks/{$truck->id}")->assertOk();

        $this->assertSame('T 999 XYZ', $job->fresh()->assignedTruck->registration_number);
    }
}
