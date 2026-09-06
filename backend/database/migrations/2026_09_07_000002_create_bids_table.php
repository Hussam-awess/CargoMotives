<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Shape per Backend Schema §2.8.
        Schema::create('bids', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('jobs');
            $table->foreignId('transporter_company_id')->constrained('transporter_companies');
            $table->decimal('price', 12, 2);
            $table->timestamp('estimated_pickup_time')->nullable();
            $table->text('note')->nullable();
            $table->enum('status', ['pending', 'accepted', 'rejected', 'withdrawn'])->default('pending');
            $table->boolean('is_priority')->default(false);
            $table->timestamps();

            $table->index('status');
            $table->index(['transporter_company_id', 'created_at']);
        });

        // A partial unique index, not a plain one: only one *pending* bid
        // per company per job is disallowed — a company can freely have a
        // rejected/withdrawn bid on a job it's now bidding on again (e.g.
        // after the customer's requirements changed). Laravel's Blueprint
        // has no `unique()...where()` builder for this, so it's raw SQL.
        // This one genuinely is a hard DB constraint (unlike Phase 2's
        // deliberately-not-unique company identifiers) — there's no
        // "flagging" workflow needed here, just a clean race-condition
        // guard against double-pending-bid.
        DB::statement(
            "CREATE UNIQUE INDEX bids_one_pending_per_company_per_job ON bids (job_id, transporter_company_id) WHERE status = 'pending'"
        );
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bids');
    }
};
