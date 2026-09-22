<?php

namespace App\Services\Company;

use Illuminate\Http\UploadedFile;

/**
 * Decides a verification submission's outcome without waiting on an Admin.
 *
 * What this genuinely checks, and what it deliberately does not: nothing
 * here reads the uploaded documents. There's no OCR and no BRELA/TRA
 * registry lookup, so a certificate's *authenticity* is not established by
 * any of this — only that the identifiers are well-formed, unclaimed, and
 * that a real file was actually attached. That's why a failed check routes
 * to human review rather than to rejection: these are "this looks off,
 * someone should look" signals, not proof of anything either way.
 *
 * Auto-approving on document *presence* alone would be meaningless, since
 * SubmitCompanyVerificationRequest already makes all three required — every
 * submission that reaches this point has them by definition.
 */
class CompanyAutoVerifier
{
    /**
     * A Tanzanian TRA taxpayer identification number is 9 digits, usually
     * written NNN-NNN-NNN. Separators are stripped before counting.
     */
    private const TIN_DIGITS = 9;

    /**
     * A Tanzanian NIDA national ID is 20 digits, usually written
     * NNNNNNNN-NNNNN-NNNNN-NN.
     */
    private const NATIONAL_ID_DIGITS = 20;

    private const MIN_REGISTRATION_NUMBER_LENGTH = 4;

    /**
     * Below this, an upload is a blank page, a placeholder, or a truncated
     * file rather than a real scanned document.
     */
    private const MIN_DOCUMENT_BYTES = 10240;

    public function __construct(private readonly CompanyDuplicateDetector $duplicateDetector) {}

    /**
     * @param  array<string, mixed>  $validated  the submission's validated fields
     * @param  array<string, ?UploadedFile>  $documents  label => uploaded file
     * @return array{status: string, notes: array<int, string>}
     */
    public function review(array $validated, array $documents, ?int $excludingCompanyId = null): array
    {
        $notes = [];

        $conflict = $this->duplicateDetector->conflictingCompany(
            $validated['registration_number'],
            $validated['tin'],
            $validated['rep_national_id_number'],
            $excludingCompanyId,
        );

        if ($conflict !== null) {
            $notes[] = "Matches an existing company on file (#{$conflict->id}, {$conflict->company_name}) by registration number, TIN, or representative ID.";
        }

        if ($this->digitsIn($validated['tin']) !== self::TIN_DIGITS) {
            $notes[] = 'TIN is not '.self::TIN_DIGITS.' digits.';
        }

        if ($this->digitsIn($validated['rep_national_id_number']) !== self::NATIONAL_ID_DIGITS) {
            $notes[] = 'Representative national ID is not '.self::NATIONAL_ID_DIGITS.' digits.';
        }

        $registrationNumber = preg_replace('/[^A-Za-z0-9]/', '', $validated['registration_number']) ?? '';
        if (strlen($registrationNumber) < self::MIN_REGISTRATION_NUMBER_LENGTH) {
            $notes[] = 'Company registration number is too short to look genuine.';
        }

        foreach ($documents as $label => $file) {
            if ($file !== null && $file->getSize() < self::MIN_DOCUMENT_BYTES) {
                $notes[] = "The {$label} file is too small to be a real document.";
            }
        }

        return [
            // A duplicate keeps its own distinct status (TRD §3) so Admin
            // can see the conflicting record side by side; any other failed
            // check is an ordinary "needs a human" pending review. Only a
            // completely clean submission is approved outright.
            'status' => match (true) {
                $conflict !== null => 'flagged_duplicate',
                $notes !== [] => 'pending',
                default => 'approved',
            },
            'notes' => $notes,
        ];
    }

    private function digitsIn(string $value): int
    {
        return strlen(preg_replace('/\D/', '', $value) ?? '');
    }
}
