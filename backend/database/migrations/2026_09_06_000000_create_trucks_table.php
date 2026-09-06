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
        // Shape per Backend Schema §2.3. Each truck is verified
        // independently of its company (PRD §7.2) — a company can have a
        // mix of approved/pending/rejected trucks at once.
        Schema::create('trucks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('transporter_company_id')->constrained('transporter_companies');

            $table->string('registration_number');
            $table->string('make_model');
            // Free text, deliberately not an enum: the docs never define a
            // fixed vehicle-type list, and inventing one would constrain
            // real fleets on a guess — Admin's document review is the
            // actual legitimacy check, not a rigid category match.
            $table->string('vehicle_type');
            $table->decimal('capacity_tons', 8, 2);
            // {"photos": ["<key>", ...], "registration_card": "<key>",
            //  "insurance": "<key>", "roadworthiness_permit": "<key>"}
            // — private storage keys, signed at read time (see
            // App\Services\Documents\DocumentStorage), same pattern as
            // transporter_companies.documents.
            $table->jsonb('documents')->nullable();

            $table->enum('verification_status', ['pending', 'approved', 'rejected'])->default('pending');
            $table->text('verification_rejected_reason')->nullable();

            // GPS fields (Phase 6). Created now, matching the Backend
            // Schema's full column list, but unused until then — a truck
            // is fully functional with none of these ever set (TRD §5.3's
            // graceful-degradation principle: GPS is optional, not a gate).
            $table->enum('gps_status', ['not_connected', 'connected', 'signal_lost'])->default('not_connected');
            // No FK constraint yet — gps_connections doesn't exist until
            // Phase 6, which adds it then.
            $table->unsignedBigInteger('gps_connection_id')->nullable();
            $table->string('gps_unit_id')->nullable();
            $table->decimal('last_known_lat', 9, 6)->nullable();
            $table->decimal('last_known_lng', 9, 6)->nullable();
            $table->decimal('last_known_heading', 8, 2)->nullable();
            $table->timestamp('last_known_at')->nullable();

            // Phase 4+ (job assignment) reads/writes this; Phase 3 only
            // ever creates trucks as 'idle' and never changes it.
            $table->enum('current_status', ['idle', 'on_job'])->default('idle');
            $table->boolean('is_active')->default(true);

            $table->timestamps();
            $table->softDeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('trucks');
    }
};
