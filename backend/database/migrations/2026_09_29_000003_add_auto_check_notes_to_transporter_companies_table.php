<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Why CompanyAutoVerifier sent a submission to a human instead of
     * approving it. Without this, an Admin opening the review queue sees a
     * pending company with no indication of what looked wrong — the whole
     * point of automating the clean cases is that whatever is left is there
     * for a stated reason. Empty on an auto-approved company.
     */
    public function up(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->json('auto_check_notes')->nullable()->after('verification_rejected_reason');
        });
    }

    public function down(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->dropColumn('auto_check_notes');
        });
    }
};
