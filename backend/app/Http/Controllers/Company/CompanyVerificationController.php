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
 * Representative Info with a selfie, submitted as one request. Handles
 * both the first submission and resubmission after a rejection.
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
            'business_license' => $this->documents->store($request->file('business_license'), 'companies/documents'),
        ];
        $logoKey = $request->hasFile('logo') ? $this->documents->store($request->file('logo'), 'companies/logos') : null;
        $repIdDocumentKey = $this->documents->store($request->file('rep_id_document'), 'companies/rep-documents');
        $repSelfieKey = $this->documents->store($request->file('rep_selfie'), 'companies/rep-selfies');

        $hasConflict = $this->duplicateDetector->hasConflict(
            $validated['registration_number'],
            $validated['tin'],
            $validated['rep_national_id_number'],
            excludingCompanyId: $existing?->id,
        );

        $attributes = [
            ...collect($validated)->except([
                'logo', 'business_license', 'rep_id_document', 'rep_selfie',
            ])->all(),
            'documents' => $documents,
            'logo_url' => $logoKey,
            'rep_id_document_url' => $repIdDocumentKey,
            'rep_selfie_url' => $repSelfieKey,
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
