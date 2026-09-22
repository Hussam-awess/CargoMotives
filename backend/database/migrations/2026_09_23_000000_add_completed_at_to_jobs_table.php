<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The real moment a job was marked completed (JobController::confirmDelivery())
 * — distinct from preferred_pickup_window_start/end, which are the
 * customer's originally requested schedule, not what actually happened.
 * Nullable: every job created before this migration, and every job that
 * hasn't reached 'completed' yet, has no value here. Indexed since it backs
 * both a public profile's "recent completed jobs" ordering (Phase 4) and
 * reliability-stat queries scoped to completed jobs (Phase 3).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->timestamp('completed_at')->nullable()->index();
        });
    }

    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn('completed_at');
        });
    }
};
