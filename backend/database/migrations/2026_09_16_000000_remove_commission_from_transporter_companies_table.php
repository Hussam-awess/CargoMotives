<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Phase 10.13: the platform no longer takes a commission or holds any
 * balance from transporter companies — revenue comes solely from Plus
 * subscriptions. Drops the commission_ledger table entirely and the two
 * columns on transporter_companies that tracked a company's standing
 * against it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('commission_ledger');

        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->dropColumn(['outstanding_balance', 'commission_standing']);
        });
    }

    public function down(): void
    {
        Schema::table('transporter_companies', function (Blueprint $table) {
            $table->decimal('outstanding_balance', 14, 2)->default(0);
            $table->enum('commission_standing', ['good_standing', 'on_hold'])->default('good_standing');
        });

        Schema::create('commission_ledger', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transporter_company_id')->constrained('transporter_companies');
            $table->enum('entry_type', ['charge', 'payment']);
            $table->decimal('amount', 12, 2);
            $table->decimal('balance_after', 14, 2);
            $table->foreignId('related_job_id')->nullable()->constrained('jobs');
            $table->foreignId('payment_id')->nullable()->constrained('payments');
            $table->timestamp('created_at')->useCurrent();

            $table->index(['transporter_company_id', 'created_at']);
        });
    }
};
