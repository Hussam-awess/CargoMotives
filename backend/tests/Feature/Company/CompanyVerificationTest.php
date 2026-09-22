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

    /**
     * A submission that passes every CompanyAutoVerifier check, so it is
     * auto-approved. The TIN and national ID are deliberately written with
     * their usual separators to prove those are normalised away before the
     * digit counts are applied.
     */
    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'company_name' => 'ABC Logistics',
            'registration_number' => 'REG-100001',
            'tin' => '123-456-789',
            'physical_address' => 'Plot 12, Nyerere Road, Dar es Salaam',
            'company_phone' => '+255712000001',
            'company_email' => 'ops@abclogistics.co.tz',
            'registration_certificate' => UploadedFile::fake()->create('registration-certificate.pdf', 200, 'application/pdf'),
            'tin_certificate' => UploadedFile::fake()->create('tin-certificate.pdf', 200, 'application/pdf'),
            'rep_full_name' => 'Juma Hassan',
            'rep_position' => 'Managing Director',
            'rep_national_id_number' => '19900101-12345-12345-12',
            'rep_id_document' => UploadedFile::fake()->create('id.pdf', 200, 'application/pdf'),
        ], $overrides);
    }

    public function test_a_clean_submission_is_auto_approved_without_an_admin(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload());

        $response->assertCreated()->assertJsonPath('data.verification_status', 'approved');
        $company = TransporterCompany::where('owner_user_id', $user->id)->sole();
        $this->assertSame('ABC Logistics', $company->company_name);
        $this->assertNotNull($company->verified_at);
        $this->assertNull($company->auto_check_notes);
    }

    /**
     * The one approval with no Admin behind it is the one most worth
     * logging — and the owner still has to be told they're live.
     */
    public function test_an_auto_approval_notifies_the_owner_and_is_logged(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload())->assertCreated();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $user->id,
            'type' => 'company_approved',
        ]);
        $this->assertDatabaseHas('activity_logs', ['action' => 'company_approved']);
    }

    public function test_a_malformed_tin_goes_to_a_human_instead_of_being_approved(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson(
            '/api/company/verification',
            $this->validPayload(['tin' => 'TIN-200001'])
        );

        $response->assertCreated()->assertJsonPath('data.verification_status', 'pending');
        $company = TransporterCompany::where('owner_user_id', $user->id)->sole();
        $this->assertNull($company->verified_at);
        // Admin opening the queue needs to know what looked wrong.
        $this->assertStringContainsString('TIN', implode(' ', $company->auto_check_notes));
    }

    public function test_a_malformed_national_id_goes_to_a_human(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson(
            '/api/company/verification',
            $this->validPayload(['rep_national_id_number' => '12345'])
        );

        $response->assertCreated()->assertJsonPath('data.verification_status', 'pending');
    }

    /**
     * A file small enough to be a blank page or a placeholder is exactly
     * the case auto-approval must not wave through — nothing here reads the
     * document, so its size is the only signal that it's real at all.
     */
    public function test_a_suspiciously_small_document_goes_to_a_human(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload([
            'tin_certificate' => UploadedFile::fake()->create('tin-certificate.pdf', 1, 'application/pdf'),
        ]));

        $response->assertCreated()->assertJsonPath('data.verification_status', 'pending');
        $company = TransporterCompany::where('owner_user_id', $user->id)->sole();
        $this->assertStringContainsString('TIN certificate', implode(' ', $company->auto_check_notes));
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
        $this->assertStringContainsString('signature=', $response->json('data.rep_id_document_url'));
        $this->assertStringContainsString('signature=', $response->json('data.documents.registration_certificate'));
        $this->assertStringContainsString('signature=', $response->json('data.documents.tin_certificate'));
    }

    public function test_a_selfie_is_not_required(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload());

        $response->assertCreated();
        $this->assertNull($response->json('data.rep_selfie_url'));
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

        // Not flagged — and with nothing else amiss, that means approved.
        $response->assertCreated()->assertJsonPath('data.verification_status', 'approved');
    }

    /**
     * The point of auto-verification holding a submission rather than
     * rejecting it outright: the transporter can correct whatever tripped
     * a check and resubmit immediately, without waiting on an Admin who
     * might never need to be involved at all.
     */
    public function test_can_resubmit_while_pending(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->for($user, 'owner')->create(['verification_status' => 'pending']);

        $response = $this->actingAs($user)->postJson(
            '/api/company/verification',
            $this->validPayload(['company_name' => 'ABC Logistics (corrected)'])
        );

        $response->assertOk()->assertJsonPath('data.verification_status', 'approved');
        $this->assertSame($company->id, $response->json('data.id'));
    }

    public function test_can_resubmit_while_flagged_duplicate(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();
        TransporterCompany::factory()->for($user, 'owner')->create(['verification_status' => 'flagged_duplicate']);

        $response = $this->actingAs($user)->postJson('/api/company/verification', $this->validPayload());

        $response->assertOk()->assertJsonPath('data.verification_status', 'approved');
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

        $response->assertOk()->assertJsonPath('data.verification_status', 'approved');
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

    /**
     * The transporter needs the same "why" an Admin sees, or "edit and
     * resubmit" is just guesswork.
     */
    public function test_show_returns_the_auto_check_notes_when_held(): void
    {
        Storage::fake('local');
        $user = User::factory()->transporterCompany()->create();

        $this->actingAs($user)->postJson(
            '/api/company/verification',
            $this->validPayload(['tin' => 'not-a-tin'])
        )->assertCreated()->assertJsonPath('data.verification_status', 'pending');

        // A fresh model, not the same $user object reused: submit() reads
        // $user->transporterCompany before the row exists (correctly null
        // then), and Eloquent caches that on the instance — actingAs()
        // hands subsequent simulated requests the exact same object, so
        // reusing it here would return that stale cached null instead of
        // querying the row this test just created. A real second request
        // never hits this, since production never shares one PHP object
        // across requests the way a single test method does.
        $this->actingAs($user->fresh())
            ->getJson('/api/company/verification')
            ->assertOk()
            ->assertJsonPath('data.verification_status', 'pending')
            ->assertJsonFragment(['auto_check_notes' => ['TIN is not 9 digits.']]);
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
