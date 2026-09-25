<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Mirrors jobs.dropoff_permit_reminder_sent_at (see that migration's
     * own docblock) for a Tier 3 award, which has its own independent
     * status/GPS fields and its own approach-to-drop-off to remind about.
     * No permit path/uploaded_at columns here — permits stay job-level
     * only (see the jobs-table permit-fields migration).
     */
    public function up(): void
    {
        Schema::table('job_awards', function (Blueprint $table) {
            $table->timestamp('dropoff_permit_reminder_sent_at')->nullable()->after('dropoff_arrival_notified_at');
        });
    }

    public function down(): void
    {
        Schema::table('job_awards', function (Blueprint $table) {
            $table->dropColumn('dropoff_permit_reminder_sent_at');
        });
    }
};
