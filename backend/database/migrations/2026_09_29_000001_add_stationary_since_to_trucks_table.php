<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * NormalizeGpsPositionJob sets this the moment a fresh ping's speed
     * first drops below config('gps.stationary_speed_threshold_kmh'), and
     * clears it back to null the moment speed rises above that threshold
     * again. Every ping overwrites last_known_speed_kmh with no history, so
     * this is the only place "how long has this truck been slow" is ever
     * recorded — without it, a fleet map can only ever see the most recent
     * instantaneous speed, never the duration Truck::isMoving() needs.
     */
    public function up(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->timestamp('stationary_since')->nullable()->after('last_known_speed_kmh');
        });
    }

    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->dropColumn('stationary_since');
        });
    }
};
