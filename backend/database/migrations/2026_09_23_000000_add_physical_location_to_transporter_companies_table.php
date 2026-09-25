<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A company's own "home base" pin — shown on its public profile
     * alongside the existing free-text physical_address, and editable any
     * time (not tied to the verification submission/resubmission flow,
     * since a company can relocate without anything else about it
     * changing). Deliberately separate from home_region (a Featured-only
     * free-text ranking hint for return-load suggestions, see
     * CompanyJobController::nearbyOpenJobsQuery's docblock) — these are
     * two unrelated concepts that happen to both describe "where this
     * company is," one for display, one for text-match ranking.
     */
    public function up(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->decimal('physical_lat', 10, 7)->nullable()->after('physical_address');
            $table->decimal('physical_lng', 10, 7)->nullable()->after('physical_lat');
        });
    }

    public function down(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->dropColumn(['physical_lat', 'physical_lng']);
        });
    }
};
