<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * How many trucks this bid covers (Multi-Company Split Awards epic) —
 * defaults to 1 so an ordinary job's bid, and every bid placed before this
 * migration, means exactly what it always meant. A bulk job's bid can
 * offer anywhere from 1 up to however many trucks are still uncovered.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('bids', function (Blueprint $table) {
            $table->unsignedSmallInteger('trucks_offered')->default(1)->after('price');
        });
    }

    public function down(): void
    {
        Schema::table('bids', function (Blueprint $table) {
            $table->dropColumn('trucks_offered');
        });
    }
};
