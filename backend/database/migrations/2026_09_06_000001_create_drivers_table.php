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
        // Shape per Backend Schema §2.4. No verification_status here,
        // deliberately: unlike companies and trucks, drivers are never
        // reviewed/approved by Admin (PRD §5 — a driver is just a company
        // employee, trusted by virtue of the company itself being verified).
        Schema::create('drivers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transporter_company_id')->constrained('transporter_companies');
            $table->string('full_name');
            // Contact number for the Driver Link SMS (Phase 5) — not a
            // login (drivers never have an account, PRD §5), so no OTP,
            // but still normalized the same way for delivery correctness.
            $table->string('phone_number');
            $table->string('license_number')->nullable();
            // A storage key (signed at read time, DocumentStorage), same
            // convention as every other document field in this schema —
            // despite the schema doc's plain "photo_url" name.
            $table->string('photo_url')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('drivers');
    }
};
