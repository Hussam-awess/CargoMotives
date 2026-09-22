<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * JobStatusAutoAdvancer's "arrived at drop-off" notification doesn't
     * change jobs.status (proof of delivery is still a required, manual
     * step) — without this guard, every subsequent GPS ping while the
     * truck sits at the destination would re-notify the customer.
     */
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->timestamp('dropoff_arrival_notified_at')->nullable()->after('gps_signal_status');
        });
    }

    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn('dropoff_arrival_notified_at');
        });
    }
};
