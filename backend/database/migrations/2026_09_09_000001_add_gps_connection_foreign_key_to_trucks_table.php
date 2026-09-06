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
        // trucks.gps_connection_id was created back in Phase 3 without a
        // real FK constraint, since gps_connections didn't exist yet
        // (see that migration's comment) — added now that it does.
        Schema::table('trucks', function (Blueprint $table) {
            $table->foreign('gps_connection_id')->references('id')->on('gps_connections');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->dropForeign(['gps_connection_id']);
        });
    }
};
