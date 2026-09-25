<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Tells apart a real driver/company submission from one the grace-period
     * auto-complete sweep created on its own (see
     * App\Console\Commands\AutoCompleteStuckDeliveries and
     * App\Services\Jobs\ProofOfDeliveryService) — the only fact the UI needs
     * to show "Automatically completed" instead of blank recipient/photos.
     */
    public function up(): void
    {
        Schema::table('proof_of_deliveries', function (Blueprint $table) {
            $table->boolean('is_system_generated')->default(false)->after('notes');
        });
    }

    public function down(): void
    {
        Schema::table('proof_of_deliveries', function (Blueprint $table) {
            $table->dropColumn('is_system_generated');
        });
    }
};
