<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 10.15: a standalone Admin<->User "Support" channel, separate from
 * the per-job Message thread (App\Models\Message) — a support thread
 * belongs to one user's account, not one job, and Admin can send to a
 * specific user or broadcast to every Customer/every Company (one row
 * per recipient, not a single nullable-recipient row, so a user's own
 * thread query stays a plain `where('user_id', ...)`).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('support_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users'); // whose thread this belongs to
            $table->enum('author', ['admin', 'user']);
            // Set only when author='admin' — which admin sent it. Null for
            // a user's own reply (there's exactly one User row for an
            // admin, `sender_user_id` on the per-job Message model already
            // covers "which user wrote this" for the user side).
            $table->foreignId('admin_id')->nullable()->constrained('users');
            $table->text('body');
            $table->timestamp('created_at')->useCurrent();

            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('support_messages');
    }
};
