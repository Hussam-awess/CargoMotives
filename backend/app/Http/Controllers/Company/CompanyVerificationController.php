<?php

namespace App\Http\Controllers\Company;

use App\Http\Controllers\Controller;
use App\Http\Requests\Company\SubmitCompanyVerificationRequest;
use App\Http\Resources\CompanyResource;
use App\Models\TransporterCompany;
use App\Services\Company\CompanyAutoVerifier;
use App\Services\Documents\DocumentStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * The two-section verification flow (AppFlow §1): Company Info, then
 * Representative Info, submitted as one request. Handles the first
 * submission and every resubmission — after a rejection, or while
 * CompanyAutoVerifier has it held (pending/flagged_duplicate) waiting on a
 * correction. Only an already-approved company can't resubmit: there's
 * nothing left to correct once Admin (or the auto-verifier) has cleared it.
 */
class CompanyVerificationController extends Controller
{
    public function __construct(
        private readonly DocumentStorage $documents,
        private readonly CompanyAutoVerifier $autoVerifier,
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

        if ($existing && $existing->verification_status === 'approved') {
            throw ValidationException::withMessages([
                'company_name' => ['This company is already verified.'],
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

        // Automated review, so a clean submission never waits on an Admin.
        // See CompanyAutoVerifier for exactly what this does and doesn't
        // establish — notably, it never rejects, it only routes anything
        // questionable to a human.
        $review = $this->autoVerifier->review(
            $validated,
            [
                'company registration certificate' => $request->file('registration_certificate'),
                'TIN certificate' => $request->file('tin_certificate'),
                'representative ID' => $request->file('rep_id_document'),
            ],
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
            'verification_status' => $review['status'],
            'verification_rejected_reason' => null,
            'auto_check_notes' => $review['notes'] === [] ? null : $review['notes'],
            'verified_at' => $review['status'] === 'approved' ? now() : null,
        ];

        $company = $existing
            ? tap($existing)->update($attributes)
            : TransporterCompany::create([...$attributes, 'owner_user_id' => $user->id]);

        return new CompanyResource($company);
    }
}
