<?php

namespace Tests\Feature\Company;

use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Covers the two-section verification submission (AppFlow §1) and its
 * anti-duplicate rule (TRD §3, Backend Schema §4.1): a collision is
 * flagged for Admin, never silently accepted or outright rejected.
 */
class CompanyVerificationTest extends TestCase
{
    use RefreshDatabase;

    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'company_name' => 'ABC Logistics',
            'registration_number' => 'REG-100001',
            'tin' => 'TIN-200001',
            'physical_address' => 'Plot 12, Nyerere Road, Dar es Salaam',
            'company_phone' => '+255712000001',
            'company_email' => 'ops@abclogistics.co.tz',
            'registration_certificate' => UploadedFile::fake()->create('registration-certificate.pdf', 200, 'application/pdf'),
            'tin_certificate' => UploadedFile::fake()->create('tin-certificate.pdf', 200, 'application/pdf'),
            'rep_full_name' => 'Juma Hassan',
            'rep_position' => 'Managing Director',
            'rep_national_id_number' => 'NIDA-300001',
            'rep_id_document' => UploadedFile::fake()->create('id.pdf', 200, 'application/pdf'),
            'rep_selfie' => UploadedFile::fake()->create('selfie.jpg', 100, 'image/jpeg'),
        ], $overrides);
    }

    public function test_transporter_company_can_submit_verification(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload());

        $response->assertCreated()->assertJsonPath('data.verification_status', 'pending');
        $this->assertDatabaseHas('transporter_companies', [
            'owner_user_id' => $user->id,
            'company_name' => 'ABC Logistics',
            'verification_status' => 'pending',
        ]);
    }

    public function test_customer_cannot_submit_company_verification(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload())->assertForbidden();
    }

    public function test_documents_are_returned_as_signed_urls(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload());

        $response->assertCreated();
        // The storage path legitimately appears in the URL (it's a route
        // parameter) — what actually protects it is the signature, which
        // DocumentAccessTest confirms is required to fetch the file.
        $this->assertStringContainsString('signature=', $response->json('data.rep_selfie_url'));
        $this->assertStringContainsString('signature=', $response->json('data.documents.registration_certificate'));
        $this->assertStringContainsString('signature=', $response->json('data.documents.tin_certificate'));
    }

    public function test_optional_other_documents_are_stored_and_signed(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload([
            'other_documents' => [
                UploadedFile::fake()->create('permit.pdf', 100, 'application/pdf'),
                UploadedFile::fake()->create('license-extra.pdf', 100, 'application/pdf'),
            ],
        ]));

        $response->assertCreated();
        $otherDocuments = $response->json('data.documents.other_documents');
        $this->assertCount(2, $otherDocuments);
        $this->assertStringContainsString('signature=', $otherDocuments[0]);
        $this->assertStringContainsString('signature=', $otherDocuments[1]);
    }

    public function test_other_documents_is_optional(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload());

        $response->assertCreated();
        $this->assertArrayNotHasKey('other_documents', $response->json('data.documents'));
    }

    public function test_duplicate_registration_number_is_flagged_not_rejected(): void
    {
        Storage::fake('local');
        TransporterCompany::factory()->create(['registration_number' => 'REG-100001']);

        $user = User::factory()->transporterCompany()->create();
        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload());

        $response->assertCreated()->assertJsonPath('data.verification_status', 'flagged_duplicate');
    }

    public function test_duplicate_against_a_rejected_company_is_not_flagged(): void
    {
        Storage::fake('local');
        TransporterCompany::factory()->rejected()->create(['registration_number' => 'REG-100001']);

        $user = User::factory()->transporterCompany()->create();
        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload());

        $response->assertCreated()->assertJsonPath('data.verification_status', 'pending');
    }

    public function test_cannot_resubmit_while_pending(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->for($user, 'owner')->create();

        $this->actingAs($user)
            ->postJson('/api/company/verification', $this->validPayload())
            ->assertUnprocessable();
    }

    public function test_cannot_resubmit_once_approved(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->approved()->for($user, 'owner')->create();

        $this->actingAs($user)
            ->postJson('/api/company/verification', $this->validPayload())
            ->assertUnprocessable();
    }

    public function test_can_resubmit_after_rejection(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->rejected()->for($user, 'owner')->create();

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload([
            'company_name' => 'ABC Logistics (corrected)',
        ]));

        $response->assertOk()->assertJsonPath('data.verification_status', 'pending');
        $this->assertSame($company->id, $response->json('data.id'));
        $this->assertDatabaseHas('transporter_companies', [
            'id' => $company->id,
            'company_name' => 'ABC Logistics (corrected)',
            'verification_rejected_reason' => null,
        ]);
    }

    public function test_show_returns_null_data_when_no_submission_yet(): void
    {
        $user = User::factory()->transporterCompany()->create();

        $this->actingAs($user)
            ->getJson('/api/company/verification')
            ->assertOk()
            ->assertExactJson(['data' => null]);
    }

    public function test_show_returns_current_status(): void
    {
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->for($user, 'owner')->create();

        $this->actingAs($user)
            ->getJson('/api/company/verification')
            ->assertOk()
            ->assertJsonPath('data.verification_status', 'pending');
    }
}
