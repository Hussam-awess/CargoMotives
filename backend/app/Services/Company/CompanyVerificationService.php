<?php

namespace App\Services\Company;

use App\Models\TransporterCompany;
use Illuminate\Database\QueryException;

/**
 * Approving a company is more than a status flip: it's the one moment
 * that must never let two companies with the same registration_number/
 * TIN/rep_national_id_number both end up 'approved' (Phase 10 audit
 * finding — AdminCompanyController::approve() previously flipped the
 * status unconditionally, with no re-check at all, despite this
 * migration's own original comment claiming one existed "defensively
 * before Admin approval"). Two layers, matching the depth of the actual
 * risk:
 *  1. An application-layer re-check via CompanyDuplicateDetector, narrowed
 *     to an already-*approved* conflict (a pending/flagged sibling isn't
 *     itself a blocker — Admin may be about to reject it).
 *  2. A DB-level partial unique index (see this phase's migration) as the
 *     backstop for a genuine concurrent-approval race the check above
 *     can't fully close on its own — caught here and translated into the
 *     same clean exception rather than a raw QueryException.
 */
class CompanyVerificationService
{
    public function __construct(private readonly CompanyDuplicateDetector $duplicateDetector) {}

    /**
     * @throws CompanyApprovalConflictException
     */
    public function approve(TransporterCompany $company): void
    {
        $conflict = $this->duplicateDetector->conflictingCompany(
            $company->registration_number,
            $company->tin,
            $company->rep_national_id_number,
            excludingCompanyId: $company->id,
        );

        if ($conflict?->verification_status === 'approved') {
            throw new CompanyApprovalConflictException(
                "{$conflict->company_name} is already approved with a matching registration number, TIN, or NIDA number."
            );
        }

        try {
            $company->update([
                'verification_status' => 'approved',
                'verification_rejected_reason' => null,
                'verified_at' => now(),
            ]);
        } catch (QueryException $e) {
            if (self::isUniqueConstraintViolation($e)) {
                throw new CompanyApprovalConflictException(
                    'Another company was just approved with a matching registration number, TIN, or NIDA number.'
                );
            }

            throw $e;
        }
    }

    private static function isUniqueConstraintViolation(QueryException $e): bool
    {
        // SQLSTATE 23505 = unique_violation (Postgres).
        return ($e->errorInfo[0] ?? null) === '23505';
    }
}
