<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Two small, previously-nonexistent company preferences (Plus Polish):
     * `auto_decline_below_budget` + `floor_rate`/`floor_rate_currency`
     * actually filter the Open Jobs feed now (CompanyJobController::open())
     * — the mobile toggle used to exist but wrote nowhere. `display_currency`
     * is purely cosmetic (formats the company's own Plus price on
     * `featured_screen.dart`) and never affects a job's/bid's own currency,
     * which always stays whatever the posting customer chose.
     */
    public function up(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->boolean('auto_decline_below_budget')->default(false)->after('preferred_routes');
            $table->decimal('floor_rate', 12, 2)->nullable()->after('auto_decline_below_budget');
            $table->string('floor_rate_currency', 3)->default('TZS')->after('floor_rate');
            $table->string('display_currency', 3)->default('TZS')->after('floor_rate_currency');
        });
    }

    public function down(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->dropColumn(['auto_decline_below_budget', 'floor_rate', 'floor_rate_currency', 'display_currency']);
        });
    }
};
