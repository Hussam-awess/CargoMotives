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
        // Shape per Backend Schema §2.16 — one general-purpose audit trail
        // for every state-changing action from Phases 1-9 (verification,
        // job status, bids, payments, disputes), not a per-feature log
        // table. subject_type/subject_id are a plain polymorphic reference
        // (App\Models\ActivityLog::subject()); actor_user_id is nullable
        // for system-originated events (a webhook confirming a payment, a
        // queued GPS job) that have no authenticated request behind them.
        // No updated_at: an entry is never edited once written.
        Schema::create('activity_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('actor_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action');
            $table->string('subject_type');
            $table->unsignedBigInteger('subject_id');
            $table->jsonb('metadata')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['action', 'created_at']);
            $table->index(['subject_type', 'subject_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('activity_logs');
    }
};
