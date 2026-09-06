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
        // Shape per Backend Schema §2.13. Append-only — an entry is never
        // updated once written (a correction is a new entry, never an
        // edit), so this table deliberately has no updated_at; see
        // App\Models\CommissionLedger's `const UPDATED_AT = null`.
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

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('commission_ledger');
    }
};
