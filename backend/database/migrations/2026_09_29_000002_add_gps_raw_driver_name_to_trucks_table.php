<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * gps_driver_name is the DISPLAYED value; this tracks the last raw
     * value actually seen from the provider, used only for change
     * detection in NormalizeGpsPositionJob. Without this, a provider
     * device that's simply mislabeled at the source (confirmed real case:
     * a device's own driver field/name says "SULE" when the real driver is
     * "Paulo") can never be corrected in this app without the very next
     * poll silently reverting it — every poll used to overwrite
     * gps_driver_name unconditionally. Keeping the two separate lets a
     * manual correction stick as long as the provider's own raw value
     * hasn't changed, while still self-healing the moment it does.
     */
    public function up(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->string('gps_raw_driver_name')->nullable()->after('gps_driver_name');
        });
    }

    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->dropColumn('gps_raw_driver_name');
        });
    }
};
