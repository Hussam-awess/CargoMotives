<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\SubmitCompanyVerificationRequest;
use App\Http\Resources\CompanyResource;
use App\Models\TransporterCompany;
use App\Services\Company\CompanyDuplicateDetector;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * The two-section verification flow (AppFlow §1): Company Info, then
 * Representative Info, submitted as one request. Handles both the first
 * submission and resubmission after a rejection.
 */
class CompanyVerificationController extends Controller
{
    public function __construct(
        private readonly DocumentStorage $documents,
        private readonly CompanyDuplicateDetector $duplicateDetector,
    ) {}

    /**
     * Current verification status/details for the authenticated company
     * user — {"data": null} if they haven't submitted anything yet. Used
     * both to decide routing after login and for a "check again" refresh
     * while a submission is pending Admin review. Deliberately always 200
     * with a possibly-null `data` (not 204 for the "nothing yet" case) so
     * every response from this endpoint has the same shape to parse.
     */
    public function show(Request $request): CompanyResource|JsonResponse
    {
        $company = $request->user()->transporterCompany;

        return $company ? new CompanyResource($company) : response()->json(['data' => null]);
    }

    public function submit(SubmitCompanyVerificationRequest $request): CompanyResource
    {
        $user = $request->user();
        $existing = $user->transporterCompany;

        if ($existing && in_array($existing->verification_status, ['pending', 'approved'], true)) {
            throw ValidationException::withMessages([
                'company_name' => [$existing->verification_status === 'approved'
                    ? 'This company is already verified.'
                    : 'A verification submission is already under review.'],
            ]);
        }

        $validated = $request->validated();

        $documents = [
            'registration_certificate' => $this->documents->store($request->file('registration_certificate'), 'companies/documents'),
            'tin_certificate' => $this->documents->store($request->file('tin_certificate'), 'companies/documents'),
        ];
        if ($request->hasFile('other_documents')) {
            $documents['other_documents'] = collect($request->file('other_documents'))
                ->map(fn ($file) => $this->documents->store($file, 'companies/documents'))
                ->all();
        }
        $logoKey = $request->hasFile('logo') ? $this->documents->store($request->file('logo'), 'companies/logos') : null;
        $repIdDocumentKey = $this->documents->store($request->file('rep_id_document'), 'companies/rep-documents');

        $hasConflict = $this->duplicateDetector->hasConflict(
            $validated['registration_number'],
            $validated['tin'],
            $validated['rep_national_id_number'],
            excludingCompanyId: $existing?->id,
        );

        $attributes = [
            ...collect($validated)->except([
                'logo', 'registration_certificate', 'tin_certificate', 'other_documents', 'rep_id_document',
            ])->all(),
            'documents' => $documents,
            'logo_url' => $logoKey,
            'rep_id_document_url' => $repIdDocumentKey,
            // rep_selfie_url is deliberately absent: no longer collected
            // (see this file's docblock) — omitted rather than set to null
            // so a resubmission never wipes a selfie an earlier version of
            // this form did collect for an existing company.
            // Implied by the owner account's phone already being
            // OTP-verified at signup (Phase 1) — not a second OTP step.
            'rep_phone_verified' => true,
            'rep_email_verified' => false,
            'verification_status' => $hasConflict ? 'flagged_duplicate' : 'pending',
            'verification_rejected_reason' => null,
            'verified_at' => null,
        ];

        $company = $existing
            ? tap($existing)->update($attributes)
            : TransporterCompany::create([...$attributes, 'owner_user_id' => $user->id]);

        return new CompanyResource($company);
    }
}
