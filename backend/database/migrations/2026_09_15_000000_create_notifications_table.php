<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Backend Schema §2.18, built exactly to the doc's terse column list.
 * Append-only like commission_ledger (Phase 7) — no updated_at; read_at
 * and sent_via_fcm are the only fields ever mutated after creation, both
 * simple flips rather than edits worth a full updated_at semantic.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type');
            $table->string('title');
            $table->text('body');
            $table->foreignId('related_job_id')->nullable()->constrained('jobs')->nullOnDelete();
            $table->timestamp('read_at')->nullable();
            $table->boolean('sent_via_fcm')->default(false);
            $table->timestamp('created_at')->useCurrent();

            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
