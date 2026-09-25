<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Mirrors users.featured_expiry_reminder_sent_at (see that migration's
     * own docblock) — a company's own Plus subscription expires
     * independently of any user's.
     */
    public function up(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->timestamp('featured_expiry_reminder_sent_at')->nullable()->after('featured_until');
        });
    }

    public function down(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->dropColumn('featured_expiry_reminder_sent_at');
        });
    }
};
