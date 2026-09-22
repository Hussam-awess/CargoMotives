<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Some GPS providers report a driver name against the device itself
     * (Tracksolid Pro's `driverName` field, tied to how the SIM/hardware
     * was registered on their side) — display-only, refreshed on every
     * poll alongside position, never editable in this app and never a
     * substitute for the real `drivers` table (which belongs to a job
     * assignment, not a truck). Null for providers that don't report one
     * (Wialon, Traccar) or for a device where it was never set.
     */
    public function up(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->string('gps_driver_name')->nullable()->after('last_known_speed_kmh');
        });
    }

    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->dropColumn('gps_driver_name');
        });
    }
};
