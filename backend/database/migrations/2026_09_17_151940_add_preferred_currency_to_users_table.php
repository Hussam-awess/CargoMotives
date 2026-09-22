<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tanzanian logistics pricing is quoted in USD as often as TZS — this lets
 * a customer choose which currency their own job postings are denominated
 * in (set at signup, editable in Settings afterward), defaulting to TZS
 * (this app's existing, only-ever-used currency) so every account created
 * before this migration keeps behaving exactly as it does today. Purely a
 * *denomination* choice — there is no conversion/exchange-rate system
 * here, a USD job's budget_price is a USD number, same as a TZS job's is
 * a TZS number.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('preferred_currency', 3)->default('TZS')->after('language_preference');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('preferred_currency');
        });
    }
};
