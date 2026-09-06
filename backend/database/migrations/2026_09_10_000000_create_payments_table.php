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
        // Shape per Backend Schema §2.14. Created before commission_ledger
        // (which has a nullable FK to this table) so that FK can be added
        // directly rather than in a follow-up migration.
        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users'); // the payer
            $table->enum('purpose', ['commission_payment', 'featured_company', 'featured_customer']);
            $table->decimal('amount', 12, 2);
            $table->enum('mobile_money_provider', ['mpesa', 'tigopesa', 'airtelmoney', 'other']);
            // The idempotency key (Business Rule §8: "payments are
            // processed idempotently keyed on gateway_reference") — this
            // app's own reference, sent to the gateway as the order id and
            // echoed back on its webhook, not something Selcom assigns.
            $table->string('gateway_reference')->unique();
            $table->enum('status', ['initiated', 'pending_confirmation', 'succeeded', 'failed'])->default('initiated');
            $table->jsonb('raw_gateway_payload')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payments');
    }
};
