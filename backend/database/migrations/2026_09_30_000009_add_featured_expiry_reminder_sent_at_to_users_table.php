<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Guards NotifyFeaturedExpiringSoon the same way every other
     * "fire-once" GPS/permit reminder in this app is guarded — without it,
     * every daily run inside the reminder window would re-notify the user.
     * Reset to null by FeaturedTierService::activateFromPayment() on every
     * (re-)purchase, so a renewal gets its own fresh warning cycle.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('featured_expiry_reminder_sent_at')->nullable()->after('featured_until');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('featured_expiry_reminder_sent_at');
        });
    }
};
