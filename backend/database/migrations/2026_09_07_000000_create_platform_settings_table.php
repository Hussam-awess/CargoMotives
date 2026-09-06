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
        // Shape per Backend Schema §2.17. A handful of Admin-editable
        // business values (bid/post quotas now; commission rate, hold
        // threshold, Featured pricing once Phases 7-8 need them) live here
        // as key-value rows rather than a PHP config file, since the TRD
        // (§8) ties them to a single basic Admin settings form (Phase 9) —
        // that form doesn't exist yet, but the values it will edit need to
        // be DB-driven from the moment anything reads them.
        Schema::create('platform_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->string('value');
            $table->foreignId('updated_by_admin_id')->nullable()->constrained('users');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('platform_settings');
    }
};
