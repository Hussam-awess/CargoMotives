<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Speed alongside the existing last_known_lat/lng/heading/at fields —
     * every GpsProvider now reports it (km/h, already unit-converted per
     * provider — see e.g. TraccarGpsProvider's knots conversion), so the
     * customer's live tracking screen can show it, not just position.
     */
    public function up(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->decimal('last_known_speed_kmh', 6, 2)->nullable()->after('last_known_heading');
        });
    }

    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->dropColumn('last_known_speed_kmh');
        });
    }
};
