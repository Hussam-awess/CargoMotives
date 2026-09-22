<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Mirrors jobs.dropoff_arrival_notified_at (see that migration's own
     * docblock) for a Tier 3 award, which has its own independent status/
     * GPS fields and its own drop-off arrival to notify about.
     */
    public function up(): void
    {
        Schema::table('job_awards', function (Blueprint $table) {
            $table->timestamp('dropoff_arrival_notified_at')->nullable()->after('gps_signal_status');
        });
    }

    public function down(): void
    {
        Schema::table('job_awards', function (Blueprint $table) {
            $table->dropColumn('dropoff_arrival_notified_at');
        });
    }
};
