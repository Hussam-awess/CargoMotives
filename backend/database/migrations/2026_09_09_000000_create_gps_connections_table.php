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
        // Shape per Backend Schema §2.6. One company-level account per
        // provider covers that company's whole fleet (TRD §5.1) — a truck
        // links to one of these via trucks.gps_connection_id, not its own
        // separate credentials.
        Schema::create('gps_connections', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transporter_company_id')->constrained('transporter_companies');
            // Only 'wialon' has a real integration (Phase 6 — "prove the
            // pattern with one provider before touching a second"); the
            // other values exist in the enum now so the column never needs
            // widening later, per the schema doc's future-proofing note.
            $table->enum('provider', ['wialon', 'traccar', 'tracksolid_pro', 'utrack_africa', 'easytrack']);
            // Encrypted via the model's `encrypted` cast (Eloquent
            // encrypts/decrypts transparently using APP_KEY) — never
            // stored or logged in plaintext.
            $table->text('access_token');
            $table->text('refresh_token')->nullable();
            $table->enum('status', ['connected', 'disconnected', 'error'])->default('connected');
            $table->timestamp('connected_at');
            $table->timestamp('last_synced_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('gps_connections');
    }
};
