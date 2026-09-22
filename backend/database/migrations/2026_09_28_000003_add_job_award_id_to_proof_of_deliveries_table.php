<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Scopes a proof-of-delivery to one company's award (Multi-Company Split
 * Awards epic) — null keeps today's meaning exactly (one PoD per job,
 * via Job::proofOfDelivery()).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('proof_of_deliveries', function (Blueprint $table) {
            $table->foreignId('job_award_id')->nullable()->after('job_id')->constrained('job_awards')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('proof_of_deliveries', function (Blueprint $table) {
            $table->dropConstrainedForeignId('job_award_id');
        });
    }
};
