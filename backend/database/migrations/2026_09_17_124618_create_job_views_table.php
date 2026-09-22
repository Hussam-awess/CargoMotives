<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One row per (job, company) that has ever opened this job's detail
 * (CompanyJobController::show()) — lets a Plus/Featured customer see how
 * many distinct transporters looked at their job. Append-only and
 * deduplicated at the DB level: a company re-opening the same job several
 * times only ever counts once, so this is "how many transporters are
 * interested," not "how many page loads."
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('job_views', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained()->cascadeOnDelete();
            $table->foreignId('transporter_company_id')->constrained('transporter_companies')->cascadeOnDelete();
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['job_id', 'transporter_company_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('job_views');
    }
};
