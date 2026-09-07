<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Phase 2's decision to NOT put a blanket unique constraint on
        // registration_number/tin/rep_national_id_number was correct — the
        // whole point of flagged_duplicate is that multiple pending/flagged
        // applications CAN share an identifier while Admin reviews them
        // side by side. But nothing enforced the one invariant that
        // actually matters: two companies can never BOTH be genuinely
        // approved with the same identifier. AdminCompanyController::
        // approve() only checked that at the application layer (and even
        // then, only for display via conflictSummary(), never as an
        // approval gate) — a real gap a Phase 10 security/regression audit
        // caught: two concurrent approvals of conflicting flagged_duplicate
        // companies could both succeed. A partial unique index scoped to
        // WHERE verification_status = 'approved' closes this at the
        // database level without touching the pending/flagged coexistence
        // the flagging workflow depends on. See
        // App\Services\Company\CompanyVerificationService, which now
        // re-checks before approving AND catches this index's violation as
        // a last-resort backstop for a true concurrent-approval race.
        DB::statement(
            "CREATE UNIQUE INDEX transporter_companies_approved_registration_number ON transporter_companies (registration_number) WHERE verification_status = 'approved'"
        );
        DB::statement(
            "CREATE UNIQUE INDEX transporter_companies_approved_tin ON transporter_companies (tin) WHERE verification_status = 'approved'"
        );
        DB::statement(
            "CREATE UNIQUE INDEX transporter_companies_approved_rep_national_id_number ON transporter_companies (rep_national_id_number) WHERE verification_status = 'approved'"
        );
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS transporter_companies_approved_registration_number');
        DB::statement('DROP INDEX IF EXISTS transporter_companies_approved_tin');
        DB::statement('DROP INDEX IF EXISTS transporter_companies_approved_rep_national_id_number');
    }
};
