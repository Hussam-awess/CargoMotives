<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Bidding Deadline epic. Both nullable so every job posted before this
 * feature existed is treated as "no deadline" — exactly today's indefinite-
 * until-accepted behavior — with no backfill needed. `bidding_expires_at`
 * is indexed since NotifyBiddingClosed's sweep scans it directly.
 * `bidding_expiry_notified_at` is a guard column so that sweep never sends
 * its one-time notification twice.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->timestamp('bidding_expires_at')->nullable()->after('preferred_pickup_window_end')->index();
            $table->timestamp('bidding_expiry_notified_at')->nullable()->after('bidding_expires_at');
        });
    }

    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn(['bidding_expires_at', 'bidding_expiry_notified_at']);
        });
    }
};
