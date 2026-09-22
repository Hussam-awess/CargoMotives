<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Marks a truck created directly from a GPS provider's device list
     * (GpsConnectionController::import()'s "add as new truck" path) rather
     * than through the normal registration form — it has no real
     * make/model/capacity/photos/documents yet, just a plate parsed from
     * the device name and a live GPS link. Manage Fleet uses this to show
     * an "Imported from {provider}" label and an "Add details" action;
     * TruckController::update() uses it to allow editing an
     * otherwise-approved truck (see that method's own docblock). Cleared
     * back to false the moment a company actually submits real details
     * through that same edit flow.
     */
    public function up(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->boolean('is_gps_imported')->default(false)->after('gps_driver_name');
        });
    }

    public function down(): void
    {
        Schema::table('trucks', function (Blueprint $table) {
            $table->dropColumn('is_gps_imported');
        });
    }
};
