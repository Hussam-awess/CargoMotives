<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Phase 10 audit finding: CheckGpsSignalLoss's query
        // (`WHERE assignedTruck.last_known_at < cutoff`) can never match a
        // NULL last_known_at — a truck marked GPS-connected at assignment
        // (JobAssignmentService sets gps_signal_status='ok' optimistically)
        // that then never sends a single real position (bad unit ID,
        // device off) sits in 'ok' forever, showing a misleading "live"
        // indicator rather than TRD §5.3's "GPS signal unavailable" state.
        // This column gives that specific case something to measure
        // elapsed time against, since last_known_at itself is NULL.
        Schema::table('jobs', function (Blueprint $table) {
            $table->timestamp('gps_tracking_started_at')->nullable()->after('gps_signal_status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn('gps_tracking_started_at');
        });
    }
};
