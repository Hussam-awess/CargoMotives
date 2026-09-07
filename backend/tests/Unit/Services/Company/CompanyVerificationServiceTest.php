<?php

namespace Tests\Unit\Services\Company;

use App\Models\TransporterCompany;
use App\Services\Company\CompanyApprovalConflictException;
use App\Services\Company\CompanyVerificationService;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * A Phase 10 audit finding: approving a company previously flipped its
 * status unconditionally, with no re-check at all, despite the
 * transporter_companies migration's own comment claiming a check happened
 * "defensively before Admin approval." Two companies with the same
 * registration_number/TIN/rep_national_id_number could both end up
 * 'approved'. This proves the real fix — both the application-layer
 * re-check and the DB-level partial unique index backstop.
 */
class CompanyVerificationServiceTest extends TestCase
{
    use RefreshDatabase;

    private function service(): CompanyVerificationService
    {
        return $this->app->make(CompanyVerificationService::class);
    }

    public function test_approves_a_pending_company_with_no_conflict(): void
    {
        $company = TransporterCompany::factory()->create(['verification_status' => 'pending']);

        $this->service()->approve($company);

        $company->refresh();
        $this->assertSame('approved', $company->verification_status);
        $this->assertNotNull($company->verified_at);
    }

    public function test_refuses_to_approve_a_flagged_duplicate_whose_conflict_is_already_approved(): void
    {
        $approved = TransporterCompany::factory()->approved()->create([
            'registration_number' => 'REG-1', 'tin' => 'TIN-1', 'rep_national_id_number' => 'NIDA-1',
        ]);
        $flagged = TransporterCompany::factory()->flaggedDuplicate()->create([
            'registration_number' => 'REG-1', 'tin' => 'TIN-2', 'rep_national_id_number' => 'NIDA-2',
        ]);

        $this->expectException(CompanyApprovalConflictException::class);
        $this->service()->approve($flagged);

        $this->assertSame('flagged_duplicate', $flagged->fresh()->verification_status);
    }

    public function test_allows_approving_a_flagged_duplicate_whose_conflict_is_only_pending(): void
    {
        // A conflict that's still pending/flagged (not itself approved)
        // isn't a blocker — Admin may be about to reject that other one.
        // Only an already-approved conflict must stop this approval.
        TransporterCompany::factory()->create([
            'verification_status' => 'pending',
            'registration_number' => 'REG-1', 'tin' => 'TIN-1', 'rep_national_id_number' => 'NIDA-1',
        ]);
        $flagged = TransporterCompany::factory()->flaggedDuplicate()->create([
            'registration_number' => 'REG-1', 'tin' => 'TIN-2', 'rep_national_id_number' => 'NIDA-2',
        ]);

        $this->service()->approve($flagged);

        $this->assertSame('approved', $flagged->fresh()->verification_status);
    }

    public function test_the_database_itself_refuses_two_approved_companies_sharing_a_registration_number(): void
    {
        // The real backstop for a genuine concurrent-approval race that
        // the application-layer pre-check can't fully close on its own —
        // proves the partial unique index (this phase's migration) is
        // actually in place and enforced at the database level, entirely
        // independent of CompanyVerificationService's own pre-check
        // (which is what the other tests above exercise). A raw model
        // save bypasses the service on purpose here.
        TransporterCompany::factory()->approved()->create(['registration_number' => 'REG-SAME']);
        $second = TransporterCompany::factory()->create([
            'verification_status' => 'flagged_duplicate',
            'registration_number' => 'REG-SAME',
        ]);

        $this->expectException(QueryException::class);
        $second->verification_status = 'approved';
        $second->save();
    }
}
