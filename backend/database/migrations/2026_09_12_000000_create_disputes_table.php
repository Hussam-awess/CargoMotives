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
        // Shape per Backend Schema §2.12. A customer raises one via "Report
        // a Problem" (the AppFlow alternative to confirming delivery);
        // Admin's Disputes tool (Phase 9, PRD §10 item 8) reviews it against
        // the job's proof of delivery and GPS history and resolves it.
        Schema::create('disputes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs');
            $table->foreignId('raised_by_user_id')->constrained('users');
            $table->text('reason');
            $table->enum('status', ['open', 'under_review', 'resolved'])->default('open');
            $table->text('resolution_note')->nullable();
            $table->foreignId('resolved_by_admin_id')->nullable()->constrained('users');
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('disputes');
    }
};
