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
        Schema::table('users', function (Blueprint $table) {
            // A DocumentStorage key, not a raw URL — same private+signed
            // pattern as company_logo_url. A personal profile photo for
            // the account holder, distinct from a Customer's optional
            // business logo (company_logo_url) and a TransporterCompany's
            // own logo (a different model entirely).
            $table->string('avatar_url')->nullable()->after('full_name');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['avatar_url']);
        });
    }
};
