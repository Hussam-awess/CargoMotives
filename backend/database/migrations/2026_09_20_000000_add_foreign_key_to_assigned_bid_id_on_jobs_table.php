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
        // jobs.assigned_bid_id was created (2026_09_07_000001) before the
        // bids table existed, so it was left as a plain unconstrained
        // column — every sibling assignment column on this table
        // (assigned_company_id/assigned_truck_id/assigned_driver_id) has
        // a real FK. Adding it now that bids exists closes that gap.
        Schema::table('jobs', function (Blueprint $table) {
            $table->foreign('assigned_bid_id')->references('id')->on('bids');
            $table->index('assigned_bid_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropForeign(['assigned_bid_id']);
            $table->dropIndex(['assigned_bid_id']);
        });
    }
};
