<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * New — not in the Backend Schema doc, same justification as Phase 6's
 * gps_connections: a genuinely new piece of infrastructure needed to
 * support a documented feature (push notifications, TRD §1/§12) that has
 * no natural home in an existing table.
 *
 * One row per (user, device install) — a user can be logged in on more
 * than one device, and re-registering the same token (app reinstall, a
 * token refresh, or a different account logging in on the same physical
 * device) upserts by the token itself rather than growing duplicates.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('token')->unique();
            $table->enum('platform', ['android', 'ios', 'web']);
            $table->timestamps();

            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
    }
};
