<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A transporter company choosing to follow a specific customer, so
 * JobObserver can notify only interested companies when that customer
 * posts a new job — replacing the old "notify every approved company"
 * broadcast. A plain join row, not a status flip: unfollowing deletes the
 * row outright, there's no history requirement here.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_follows', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transporter_company_id')->constrained('transporter_companies')->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['transporter_company_id', 'customer_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_follows');
    }
};
