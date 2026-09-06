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
        // Shape per Backend Schema §2.9. Throttled route-replay history —
        // NOT a raw-ping table (TRD §5.2 explicitly rules that out). The
        // live map reads trucks.last_known_* directly; this table exists
        // purely so a dispute can reconstruct a rough route afterward.
        Schema::create('job_location_snapshots', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs');
            $table->foreignId('truck_id')->constrained('trucks');
            $table->geography('location', subtype: 'point', srid: 4326);
            $table->timestamp('recorded_at');

            $table->index(['job_id', 'recorded_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('job_location_snapshots');
    }
};
