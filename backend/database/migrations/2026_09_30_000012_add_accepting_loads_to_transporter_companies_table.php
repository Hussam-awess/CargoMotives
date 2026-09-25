<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A company pausing new work while its fleet is committed. When false,
     * JobObserver skips this company's "new job posted" alerts; the Open
     * Jobs feed itself stays browsable so the company can still look.
     */
    public function up(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->boolean('accepting_loads')->default(true)->after('display_currency');
        });
    }

    public function down(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->dropColumn('accepting_loads');
        });
    }
};
