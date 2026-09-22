<?php

namespace Tests\Unit\Services\Company;

use App\Models\TransporterCompany;
use App\Services\Company\CompanyAutoVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class CompanyAutoVerifierTest extends TestCase
{
    use RefreshDatabase;

    private function verifier(): CompanyAutoVerifier
    {
        return $this->app->make(CompanyAutoVerifier::class);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function submission(array $overrides = []): array
    {
        return array_merge([
            'registration_number' => 'REG-100001',
            'tin' => '123456789',
            'rep_national_id_number' => '19900101123451234512',
        ], $overrides);
    }

    /**
     * @return array<string, UploadedFile>
     */
    private function documents(): array
    {
        return [
            'company registration certificate' => UploadedFile::fake()->create('reg.pdf', 200, 'application/pdf'),
            'TIN certificate' => UploadedFile::fake()->create('tin.pdf', 200, 'application/pdf'),
            'representative ID' => UploadedFile::fake()->create('id.pdf', 200, 'application/pdf'),
        ];
    }

    public function test_a_clean_submission_is_approved_with_no_notes(): void
    {
        $result = $this->verifier()->review($this->submission(), $this->documents());

        $this->assertSame('approved', $result['status']);
        $this->assertSame([], $result['notes']);
    }

    public function test_separators_in_the_tin_and_national_id_are_normalised_away(): void
    {
        $result = $this->verifier()->review($this->submission([
            'tin' => '123-456-789',
            'rep_national_id_number' => '19900101-12345-12345-12',
        ]), $this->documents());

        $this->assertSame('approved', $result['status']);
    }

    public function test_a_tin_of_the_wrong_length_is_sent_to_review_not_rejected(): void
    {
        $result = $this->verifier()->review($this->submission(['tin' => '1234']), $this->documents());

        // Deliberately 'pending', never 'rejected': nothing here proves the
        // submission is bad, only that it needs a human.
        $this->assertSame('pending', $result['status']);
        $this->assertCount(1, $result['notes']);
    }

    public function test_a_national_id_of_the_wrong_length_is_sent_to_review(): void
    {
        $result = $this->verifier()->review(
            $this->submission(['rep_national_id_number' => '123']),
            $this->documents()
        );

        $this->assertSame('pending', $result['status']);
    }

    public function test_a_too_short_registration_number_is_sent_to_review(): void
    {
        $result = $this->verifier()->review($this->submission(['registration_number' => 'A-1']), $this->documents());

        $this->assertSame('pending', $result['status']);
    }

    public function test_a_tiny_document_is_sent_to_review(): void
    {
        $documents = $this->documents();
        $documents['TIN certificate'] = UploadedFile::fake()->create('tin.pdf', 1, 'application/pdf');

        $result = $this->verifier()->review($this->submission(), $documents);

        $this->assertSame('pending', $result['status']);
        $this->assertStringContainsString('TIN certificate', $result['notes'][0]);
    }

    public function test_a_duplicate_keeps_its_own_flagged_status(): void
    {
        TransporterCompany::factory()->approved()->create(['tin' => '123456789']);

        $result = $this->verifier()->review($this->submission(), $this->documents());

        $this->assertSame('flagged_duplicate', $result['status']);
        $this->assertStringContainsString('Matches an existing company', $result['notes'][0]);
    }

    /**
     * A duplicate outranks the other checks — Admin needs the conflicting
     * record put in front of them, which only the flagged status does.
     */
    public function test_a_duplicate_outranks_an_ordinary_failed_check(): void
    {
        TransporterCompany::factory()->approved()->create(['tin' => '123456789']);

        $result = $this->verifier()->review($this->submission(['registration_number' => 'A-1']), $this->documents());

        $this->assertSame('flagged_duplicate', $result['status']);
        $this->assertCount(2, $result['notes']);
    }

    public function test_an_existing_companys_own_record_is_not_a_duplicate_of_itself(): void
    {
        $company = TransporterCompany::factory()->rejected()->create(['tin' => '123456789']);

        $result = $this->verifier()->review($this->submission(), $this->documents(), excludingCompanyId: $company->id);

        $this->assertSame('approved', $result['status']);
    }
}
