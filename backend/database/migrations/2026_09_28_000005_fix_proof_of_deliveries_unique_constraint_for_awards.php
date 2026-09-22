<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A real bug caught during live verification of the Multi-Company Split
 * Awards epic: the original `unique('job_id')` constraint (Backend Schema
 * §2.10 — "a job is delivered at most once") predates job_award_id and
 * still applies to every row regardless of it, so a job's SECOND award
 * submitting its own proof of delivery hit a duplicate-key error on the
 * exact same job_id, even though it's a completely different award.
 *
 * Replaced with two partial unique indexes (Postgres-native, not
 * expressible as a plain composite unique — a composite `unique(job_id,
 * job_award_id)` would let job_award_id IS NULL rows collide silently,
 * since Postgres never treats two NULLs as equal in a uniqueness check):
 *  - one PoD per job when job_award_id IS NULL (today's exact Tier 1/2
 *    invariant, preserved byte-for-byte).
 *  - one PoD per award when job_award_id IS NOT NULL (the Tier 3
 *    equivalent — one submission per company's own slice).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('proof_of_deliveries', function (Blueprint $table) {
            $table->dropUnique('proof_of_deliveries_job_id_unique');
        });

        DB::statement('CREATE UNIQUE INDEX proof_of_deliveries_job_id_unique_no_award ON proof_of_deliveries (job_id) WHERE job_award_id IS NULL');
        DB::statement('CREATE UNIQUE INDEX proof_of_deliveries_job_award_id_unique ON proof_of_deliveries (job_award_id) WHERE job_award_id IS NOT NULL');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS proof_of_deliveries_job_id_unique_no_award');
        DB::statement('DROP INDEX IF EXISTS proof_of_deliveries_job_award_id_unique');

        Schema::table('proof_of_deliveries', function (Blueprint $table) {
            $table->unique('job_id');
        });
    }
};
