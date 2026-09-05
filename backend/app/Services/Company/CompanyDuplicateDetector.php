<?php

namespace App\Services\Company;

use App\Models\TransporterCompany;

/**
 * Implements the TRD §3 anti-duplicate rule: a registration_number, TIN, or
 * representative NIDA number that matches an existing company is flagged
 * for Admin review, not rejected or silently accepted (Backend Schema §4.1).
 *
 * A 'rejected' company's identifiers are treated as free — rejection means
 * the submission didn't check out (or was abandoned), so a later, unrelated
 * submission with a coincidentally matching detail shouldn't be blocked by
 * it forever. Anything still live (pending, approved, or already flagged)
 * counts as a claim worth flagging against.
 */
class CompanyDuplicateDetector
{
    private const LIVE_STATUSES = ['pending', 'approved', 'flagged_duplicate'];

    public function hasConflict(
        string $registrationNumber,
        string $tin,
        string $repNationalIdNumber,
        ?int $excludingCompanyId = null,
    ): bool {
        return $this->conflictingCompany($registrationNumber, $tin, $repNationalIdNumber, $excludingCompanyId) !== null;
    }

    /**
     * The specific conflicting record, so it can be shown to Admin
     * "next to" this submission for a manual call (TRD §3).
     */
    public function conflictingCompany(
        string $registrationNumber,
        string $tin,
        string $repNationalIdNumber,
        ?int $excludingCompanyId = null,
    ): ?TransporterCompany {
        return TransporterCompany::query()
            ->whereIn('verification_status', self::LIVE_STATUSES)
            ->when($excludingCompanyId, fn ($query) => $query->whereKeyNot($excludingCompanyId))
            ->where(function ($query) use ($registrationNumber, $tin, $repNationalIdNumber) {
                $query->where('registration_number', $registrationNumber)
                    ->orWhere('tin', $tin)
                    ->orWhere('rep_national_id_number', $repNationalIdNumber);
            })
            ->first();
    }
}
