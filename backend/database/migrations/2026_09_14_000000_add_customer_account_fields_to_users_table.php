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
        // Customer signup is now email+password (verified once via an
        // emailed code) instead of phone+SMS-OTP — see
        // App\Http\Controllers\Auth\CustomerAuthController. Transporter
        // Company keeps the original phone+SMS-OTP flow unchanged.
        Schema::table('users', function (Blueprint $table) {
            // A Customer's optional business identity — shown to companies
            // bidding on their jobs (see JobResource), not verified by
            // Admin the way a TransporterCompany is; purely a display
            // label the customer sets about themselves.
            $table->string('company_name')->nullable()->after('full_name');
            // A DocumentStorage key, not a raw URL — same private+signed
            // pattern as TransporterCompany.logo_url (see CompanyResource).
            $table->string('company_logo_url')->nullable()->after('company_name');
            // Set the moment a Customer's registration email-OTP succeeds.
            // Nullable/unused for transporter_company and admin accounts,
            // which verify by phone-OTP and password respectively.
            $table->timestamp('email_verified_at')->nullable()->after('email');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['company_name', 'company_logo_url', 'email_verified_at']);
        });
    }
};
