<?php

namespace Tests\Unit\Services\Company;

use App\Models\TransporterCompany;
use App\Services\Company\CompanyDuplicateDetector;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CompanyDuplicateDetectorTest extends TestCase
{
    use RefreshDatabase;

    private CompanyDuplicateDetector $detector;

    protected function setUp(): void
    {
        parent::setUp();
        $this->detector = new CompanyDuplicateDetector;
    }

    public function test_detects_conflict_on_registration_number(): void
    {
        TransporterCompany::factory()->create(['registration_number' => 'REG-1']);

        $this->assertTrue($this->detector->hasConflict('REG-1', 'TIN-other', 'NIDA-other'));
    }

    public function test_detects_conflict_on_tin(): void
    {
        TransporterCompany::factory()->create(['tin' => 'TIN-1']);

        $this->assertTrue($this->detector->hasConflict('REG-other', 'TIN-1', 'NIDA-other'));
    }

    public function test_detects_conflict_on_rep_national_id_number(): void
    {
        TransporterCompany::factory()->create(['rep_national_id_number' => 'NIDA-1']);

        $this->assertTrue($this->detector->hasConflict('REG-other', 'TIN-other', 'NIDA-1'));
    }

    public function test_no_conflict_when_nothing_matches(): void
    {
        TransporterCompany::factory()->create(['registration_number' => 'REG-1']);

        $this->assertFalse($this->detector->hasConflict('REG-2', 'TIN-2', 'NIDA-2'));
    }

    public function test_a_rejected_companys_identifiers_are_not_a_conflict(): void
    {
        TransporterCompany::factory()->rejected()->create(['registration_number' => 'REG-1']);

        $this->assertFalse($this->detector->hasConflict('REG-1', 'TIN-other', 'NIDA-other'));
    }

    public function test_excludes_the_given_company_id_so_updating_your_own_record_is_not_a_self_conflict(): void
    {
        $company = TransporterCompany::factory()->create(['registration_number' => 'REG-1']);

        $this->assertFalse(
            $this->detector->hasConflict('REG-1', 'TIN-other', 'NIDA-other', excludingCompanyId: $company->id)
        );
    }

    public function test_conflicting_company_returns_the_specific_matching_record(): void
    {
        $company = TransporterCompany::factory()->create(['registration_number' => 'REG-1']);

        $conflict = $this->detector->conflictingCompany('REG-1', 'TIN-other', 'NIDA-other');

        $this->assertSame($company->id, $conflict->id);
    }
}
