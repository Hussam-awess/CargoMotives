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
        // Shape per Backend Schema §2.1. account_type distinguishes the three
        // participant types that ever log in (Driver has no account — PRD
        // §5 — Admin gets its own web login in Phase 9); phone_number is the
        // actual login identity (OTP-based, Phase 1), email is optional.
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->enum('account_type', ['customer', 'transporter_company', 'admin']);
            $table->string('phone_number')->unique();
            $table->string('email')->nullable()->unique();
            $table->string('password_hash')->nullable();
            // Nullable: a transporter_company user's display name is the
            // company's rep_full_name (Backend Schema §2.2), set once Phase
            // 2 creates the transporter_companies row — not at signup time.
            $table->string('full_name')->nullable();
            $table->enum('status', ['active', 'suspended'])->default('active');
            $table->enum('language_preference', ['sw', 'en'])->default('sw');
            $table->boolean('is_featured')->default(false);
            $table->timestamp('featured_until')->nullable();
            $table->rememberToken();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('users');
        Schema::dropIfExists('sessions');
    }
};
