<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\CompanyResource;
use App\Models\TransporterCompany;
use App\Services\Company\CompanyApprovalConflictException;
use App\Services\Company\CompanyDuplicateDetector;
use App\Services\Company\CompanyVerificationService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

/**
 * Minimal Admin review tooling for company verification (PRD §10 items 1
 * and 8 in miniature — the full Admin Livewire tool is Phase 9). Covers
 * this phase's stated deliverable: "Admin can approve/reject/resolve a
 * duplicate."
 */
class AdminCompanyController extends Controller
{
    public function __construct(
        private readonly CompanyDuplicateDetector $duplicateDetector,
        private readonly CompanyVerificationService $verificationService,
    ) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $query = TransporterCompany::query()->latest();

        if ($status = $request->string('status')->toString()) {
            $query->where('verification_status', $status);
        }

        return CompanyResource::collection($query->paginate(20));
    }

    public function show(TransporterCompany $company): CompanyResource
    {
        return (new CompanyResource($company))->additional([
            // TRD §3: a flagged submission is shown "next to the
            // conflicting existing record" so Admin can compare and make
            // the call, rather than just seeing a bare "duplicate" flag.
            'conflicting_company' => $company->verification_status === 'flagged_duplicate'
                ? $this->conflictSummary($company)
                : null,
        ]);
    }

    public function approve(TransporterCompany $company): CompanyResource
    {
        try {
            $this->verificationService->approve($company);
        } catch (CompanyApprovalConflictException $e) {
            throw ValidationException::withMessages(['verification_status' => [$e->getMessage()]]);
        }

        return new CompanyResource($company->fresh());
    }

    public function reject(Request $request, TransporterCompany $company): CompanyResource
    {
        $request->validate(['reason' => ['required', 'string', 'max:1000']]);

        $company->update([
            'verification_status' => 'rejected',
            'verification_rejected_reason' => $request->string('reason'),
            'verified_at' => null,
        ]);

        return new CompanyResource($company);
    }

    /**
     * @return array<string, mixed>|null
     */
    private function conflictSummary(TransporterCompany $company): ?array
    {
        $conflict = $this->duplicateDetector->conflictingCompany(
            $company->registration_number,
            $company->tin,
            $company->rep_national_id_number,
            excludingCompanyId: $company->id,
        );

        return $conflict ? [
            'id' => $conflict->id,
            'company_name' => $conflict->company_name,
            'registration_number' => $conflict->registration_number,
            'tin' => $conflict->tin,
            'rep_national_id_number' => $conflict->rep_national_id_number,
            'verification_status' => $conflict->verification_status,
        ] : null;
    }
}
