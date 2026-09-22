<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * How many trucks a job requires (Bulk Cargo epic) — defaults to 1 so every
 * pre-existing job, and every ordinary job posted from now on, is
 * indistinguishable from today's single-truck jobs. Only a value > 1 opts a
 * job into the multi-truck roster path (see job_truck_assignments).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->unsignedSmallInteger('trucks_needed')->default(1)->after('container_size');
        });
    }

    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropColumn('trucks_needed');
        });
    }
};
