<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Guards JobStatusAutoAdvancer's "prepare the drop-off permit" reminder
     * (fired ~2km out) the same way dropoff_arrival_notified_at guards the
     * later "arrived" notification — without it, every GPS ping inside the
     * radius would re-notify the customer.
     */
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->timestamp('dropoff_permit_reminder_sent_at')->nullable()->after('dropoff_permit_uploaded_at');
        });
    }

    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn('dropoff_permit_reminder_sent_at');
        });
    }
};
