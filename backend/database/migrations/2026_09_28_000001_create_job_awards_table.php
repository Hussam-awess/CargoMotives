<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One company's committed slice of a multi-company bulk job (Multi-Company
 * Split Awards epic) — only ever created when a single accepted bid does
 * NOT, by itself, cover the job's entire jobs.trucks_needed. A job fully
 * covered by one company's bid never gets a row here at all; it keeps
 * using jobs.assigned_company_id/assigned_bid_id exactly as before this
 * epic (see BidController::accept()).
 *
 * status/gps_* mirror jobs' own equivalent columns — deliberately plain
 * strings, not a DB enum/CHECK constraint, so this vocabulary can grow
 * later without a fragile constraint-rebuild migration (the same reason
 * jobs.status itself was left alone rather than adding a new value here).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('job_awards', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs')->cascadeOnDelete();
            $table->foreignId('bid_id')->constrained('bids');
            $table->foreignId('transporter_company_id')->constrained('transporter_companies');
            $table->unsignedSmallInteger('trucks_offered');
            $table->decimal('agreed_price', 12, 2);
            $table->string('status')->default('assigned');
            $table->boolean('gps_tracking_active')->default(false);
            $table->string('gps_signal_status')->default('not_applicable');
            $table->timestamp('gps_tracking_started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->unique(['job_id', 'transporter_company_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('job_awards');
    }
};
