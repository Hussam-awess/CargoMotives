<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Two-way ratings (Phase: ratings): a completed job produces at most two
 * reviews — the customer rating the transporter, and the transporter
 * rating the customer — so one table with a rater_type discriminator is
 * simpler than two direction-specific tables. Append-only, same as
 * notifications/activity_logs: no edits after submission.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('job_reviews', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs')->cascadeOnDelete();
            $table->enum('rater_type', ['customer', 'transporter_company']);
            $table->foreignId('rater_user_id')->constrained('users');
            // Exactly one of these two is set, matching rater_type: the
            // customer being rated (when a transporter is the rater) or
            // the company being rated (when the customer is the rater).
            $table->foreignId('ratee_customer_id')->nullable()->constrained('users')->cascadeOnDelete();
            $table->foreignId('ratee_company_id')->nullable()->constrained('transporter_companies')->cascadeOnDelete();
            $table->unsignedTinyInteger('rating');
            $table->text('comment')->nullable();
            // Direction-specific category ratings (customer->transporter:
            // punctuality/vehicle_condition/professionalism; transporter->
            // customer: communication/cargo_accuracy/payment_promptness) —
            // three fixed keys per direction doesn't justify a lookup
            // table, validated in StoreJobReviewRequest instead.
            $table->jsonb('category_ratings')->nullable();
            $table->timestamp('created_at')->useCurrent();

            // One rating per (job, rater) — a DB-level guard, not just app
            // logic, against submitting twice for the same job.
            $table->unique(['job_id', 'rater_user_id']);
            $table->index('ratee_customer_id');
            $table->index('ratee_company_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('job_reviews');
    }
};
