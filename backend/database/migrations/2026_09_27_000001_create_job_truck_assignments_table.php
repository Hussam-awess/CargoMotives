<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The full roster of truck+driver pairs committed to a multi-truck job
 * (Bulk Cargo epic) — only ever populated for jobs.trucks_needed > 1. An
 * ordinary single-truck job keeps using jobs.assigned_truck_id/
 * assigned_driver_id exactly as before and never gets a row here.
 *
 * is_lead marks the one row (always the first assigned) whose truck/driver
 * also became the job's assigned_truck_id/assigned_driver_id — the single
 * pair that drives this job's shared status/GPS/proof-of-delivery, since
 * v1 deliberately tracks the whole multi-truck job as one shared unit, not
 * N independent ones. Every other row is a roster member only.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('job_truck_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs')->cascadeOnDelete();
            $table->foreignId('truck_id')->constrained('trucks');
            $table->foreignId('driver_id')->constrained('drivers');
            $table->foreignId('driver_link_id')->nullable()->constrained('driver_links')->nullOnDelete();
            $table->boolean('is_lead')->default(false);
            $table->timestamp('assigned_at');
            $table->timestamps();

            $table->unique(['job_id', 'truck_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('job_truck_assignments');
    }
};
