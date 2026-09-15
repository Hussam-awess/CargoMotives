<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A company can now remove a driver (only while idle — not on an
     * active trip, checked in DriverController::destroy()) — soft delete,
     * not a hard one, since jobs.assigned_driver_id and driver_links both
     * hold real foreign keys to historical drivers that must keep
     * resolving correctly. Same reasoning trucks already had (Truck
     * already uses SoftDeletes).
     */
    public function up(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::table('drivers', function (Blueprint $table) {
            $table->dropSoftDeletes();
        });
    }
};
