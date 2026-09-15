<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * The customer's own stated asking price for a job, shown to a
     * transporter company before it bids — distinct from `agreed_price`
     * (set once a bid is accepted) and never written by anything but the
     * customer's own post/edit. PostJobRequest requires it on every new
     * submission; the column itself stays nullable only so jobs posted
     * before that requirement existed keep loading correctly.
     */
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->decimal('budget_price', 12, 2)->nullable()->after('cargo_description');
        });
    }

    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn('budget_price');
        });
    }
};
