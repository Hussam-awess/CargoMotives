<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Mirrors jobs.driver_instructions (see that migration's own docblock)
     * — a Tier 3 award manages its own drivers independently of the job's
     * other awarded companies, so each award needs its own note, not one
     * shared value that would leak across companies.
     */
    public function up(): void
    {
        Schema::table('job_awards', function (Blueprint $table) {
            $table->text('driver_instructions')->nullable()->after('dropoff_permit_reminder_sent_at');
        });
    }

    public function down(): void
    {
        Schema::table('job_awards', function (Blueprint $table) {
            $table->dropColumn('driver_instructions');
        });
    }
};
