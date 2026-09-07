<?php

namespace App\Services\Company;

use RuntimeException;

/**
 * Thrown by CompanyVerificationService::approve() when approving would
 * create (or race to create) two 'approved' companies sharing a
 * registration_number/TIN/rep_national_id_number. Each call site
 * translates this into whatever error shape fits it (a 422 ValidationException
 * for the API controller, an inline message for the Livewire component).
 */
class CompanyApprovalConflictException extends RuntimeException {}
