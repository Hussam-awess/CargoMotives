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
        // Shape per Backend Schema §2.10. One row per job (unique job_id) —
        // a job is delivered at most once; a driver reassignment mid-job
        // (JobAssignmentService) invalidates the old driver_link but doesn't
        // touch this table, since no proof exists until someone actually
        // submits one.
        Schema::create('proof_of_deliveries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->unique()->constrained('jobs');
            $table->foreignId('driver_id')->constrained('drivers');
            $table->foreignId('driver_link_id')->constrained('driver_links');
            $table->jsonb('photo_urls');
            $table->string('recipient_name')->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('confirmed_by_customer_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('proof_of_deliveries');
    }
};
