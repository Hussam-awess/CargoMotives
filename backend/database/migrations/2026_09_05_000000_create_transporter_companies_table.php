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
        // Shape per Backend Schema §2.2. Company + its one verified
        // representative live in a single row (company_representatives was
        // merged in per the schema doc's simplification notes) — MVP only
        // ever needs one verified rep per company.
        Schema::create('transporter_companies', function (Blueprint $table) {
            $table->id();
            $table->foreignId('owner_user_id')->unique()->constrained('users');

            // Company info
            $table->string('company_name');
            // NOT a DB-level unique constraint, deliberately: the TRD (§3)
            // requires a colliding registration_number/tin/rep NIDA to be
            // *accepted* as flagged_duplicate for Admin review, not to fail
            // the insert outright — a real UNIQUE index would make that
            // impossible. Uniqueness is enforced at the application layer
            // instead, by CompanyDuplicateDetector (checked on submission
            // and again defensively before Admin approval). Indexed for
            // that lookup's performance, not for constraint enforcement.
            $table->string('registration_number')->index();
            $table->string('tin')->index();
            $table->text('physical_address');
            $table->string('company_phone');
            $table->string('company_email')->nullable();
            $table->string('logo_url')->nullable();
            // {"business_license": "<storage key>"} — a private storage
            // key, never a browsable URL directly; see DocumentStorage.
            $table->jsonb('documents')->nullable();

            // Representative info. rep_phone_verified is set true at
            // creation, not by a second OTP: the owner user's phone number
            // (this IS the representative) was already OTP-verified at
            // signup (Phase 1) — asking again would be redundant.
            $table->string('rep_full_name');
            $table->string('rep_position');
            $table->string('rep_national_id_number')->index();
            $table->string('rep_id_document_url');
            $table->string('rep_selfie_url');
            $table->boolean('rep_phone_verified')->default(false);
            $table->boolean('rep_email_verified')->default(false);

            $table->enum('verification_status', ['pending', 'approved', 'rejected', 'flagged_duplicate'])
                ->default('pending');
            $table->text('verification_rejected_reason')->nullable();

            $table->boolean('is_featured')->default(false);
            $table->timestamp('featured_until')->nullable();

            // For return-load matching (Featured only, Phase 8) — not used
            // before then, columns exist now only because they're part of
            // this same table per the schema, not because Phase 2 needs them.
            $table->string('home_region')->nullable();
            $table->jsonb('preferred_routes')->nullable();

            $table->decimal('average_rating', 2, 1)->nullable();
            $table->integer('rating_count')->default(0);
            $table->decimal('outstanding_balance', 14, 2)->default(0);
            $table->enum('commission_standing', ['good_standing', 'on_hold'])->default('good_standing');

            $table->timestamp('verified_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('transporter_companies');
    }
};
