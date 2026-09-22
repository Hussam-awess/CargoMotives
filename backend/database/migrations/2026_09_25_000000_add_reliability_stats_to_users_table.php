<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A customer's own reliability stats (Phase: two-way ratings) — the
 * customer-side mirror of transporter_companies.average_rating/
 * rating_count, which have existed since Phase 2 but were never actually
 * written to until JobReviewObserver. Same shape, same reasoning: system-
 * computed only (never in User's #[Fillable]), recomputed from job_reviews
 * on every new review rather than incrementally maintained.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->decimal('average_rating', 2, 1)->nullable();
            $table->integer('rating_count')->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['average_rating', 'rating_count']);
        });
    }
};
