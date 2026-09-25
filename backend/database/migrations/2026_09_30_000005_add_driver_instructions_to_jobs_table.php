<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A one-way, company-editable note for the driver — the only channel
     * that exists to reach a driver at all, since they have no account and
     * no push channel (see JobAssignmentController::updateInstructions()).
     * Job-level for an ordinary/legacy-assigned job; job_awards carries its
     * own copy for a Tier 3 split job (see that migration's docblock).
     */
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->text('driver_instructions')->nullable()->after('dropoff_permit_reminder_sent_at');
        });
    }

    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn('driver_instructions');
        });
    }
};
