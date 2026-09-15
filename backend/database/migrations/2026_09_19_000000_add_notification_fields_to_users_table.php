<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * notification_preferences: a per-category opt-out map (e.g.
     * {"bids": false}), read by NotificationService::send() before it ever
     * creates a Notification row — an absent key means "on" (opt-out, not
     * opt-in, so a user who's never touched Settings still gets everything
     * the trigger map promises). Null-safe by design: a brand-new user has
     * no row here at all until they first change a toggle.
     *
     * last_active_at / last_inactivity_nudge_at back the "haven't opened
     * the app in a while" re-engagement nudge (NudgeInactiveUsers): the
     * former is touched on every authenticated request (TouchLastActive
     * middleware), the latter records when they were last nudged so the
     * command doesn't re-notify someone every single day they stay away.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->json('notification_preferences')->nullable()->after('language_preference');
            $table->timestamp('last_active_at')->nullable()->after('notification_preferences');
            $table->timestamp('last_inactivity_nudge_at')->nullable()->after('last_active_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['notification_preferences', 'last_active_at', 'last_inactivity_nudge_at']);
        });
    }
};
