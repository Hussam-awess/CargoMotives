<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Marks a bid created by CompanyJobController::claimReturnLoad() — a
 * one-tap match at the job's own posted price, not a competitive price
 * bid. Lets the customer's bid list and the notification the company
 * receives read differently ("X wants this as a return load" rather than
 * "X bid Y on your job"), while reusing BidController::accept() completely
 * unchanged: the customer still explicitly confirms it like any other bid.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('bids', function (Blueprint $table) {
            $table->boolean('is_return_load_claim')->default(false)->after('is_priority');
        });
    }

    public function down(): void
    {
        Schema::table('bids', function (Blueprint $table) {
            $table->dropColumn('is_return_load_claim');
        });
    }
};
