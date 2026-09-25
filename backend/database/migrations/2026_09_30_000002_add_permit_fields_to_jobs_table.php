<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Cargo-authority checkpoint permits (PDF/image), uploaded by the
     * Customer via JobController::submitPickupPermit()/submitDropoffPermit().
     * Job-level only — pickup/dropoff addresses are job-level, not per
     * JobAward, so a split-award job still has exactly one permit pair.
     * The pickup permit is informational; the drop-off one is a hard
     * blocker on JobAssignmentController/DriverLinkPageController's
     * submitProofOfDelivery() (see those files).
     */
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->string('pickup_permit_path')->nullable()->after('dropoff_arrival_notified_at');
            $table->timestamp('pickup_permit_uploaded_at')->nullable()->after('pickup_permit_path');
            $table->string('dropoff_permit_path')->nullable()->after('pickup_permit_uploaded_at');
            $table->timestamp('dropoff_permit_uploaded_at')->nullable()->after('dropoff_permit_path');
        });
    }

    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn([
                'pickup_permit_path', 'pickup_permit_uploaded_at',
                'dropoff_permit_path', 'dropoff_permit_uploaded_at',
            ]);
        });
    }
};
