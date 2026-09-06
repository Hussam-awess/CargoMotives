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
        // Shape per Backend Schema §2.7. This is the marketplace job, not
        // Laravel's own queue-storage "jobs" table — see the note in
        // 0001_01_01_000002_create_jobs_table for why that one was trimmed
        // to free up this name.
        Schema::create('jobs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained('users');
            $table->foreignId('assigned_company_id')->nullable()->constrained('transporter_companies');
            // Truck/driver assignment is Phase 5 — these columns exist now
            // (matching the documented schema) but nothing sets them until
            // then.
            $table->foreignId('assigned_truck_id')->nullable()->constrained('trucks');
            $table->foreignId('assigned_driver_id')->nullable()->constrained('drivers');
            $table->foreignId('assigned_bid_id')->nullable();

            $table->enum('status', [
                'open', 'assigned', 'en_route_pickup', 'picked_up', 'in_transit', 'delivered', 'completed', 'cancelled',
            ])->default('open');

            $table->text('pickup_address');
            // See App\Services\Geo\GeoPoint for why there's no matching
            // Eloquent cast — written via raw SQL, read via a query scope.
            $table->geography('pickup_location', subtype: 'point', srid: 4326);
            $table->text('dropoff_address');
            $table->geography('dropoff_location', subtype: 'point', srid: 4326);

            $table->string('container_type');
            $table->string('container_size');
            $table->decimal('approx_weight_tons', 8, 2)->nullable();
            $table->text('cargo_description')->nullable();
            $table->timestamp('preferred_pickup_window_start');
            $table->timestamp('preferred_pickup_window_end')->nullable();
            $table->text('customer_notes')->nullable();
            $table->jsonb('photo_urls')->nullable();

            $table->decimal('agreed_price', 12, 2)->nullable();
            $table->string('currency', 3)->default('TZS');

            // GPS fields — Phase 6 sets these once a job's assigned truck
            // actually has GPS connected; a job with no GPS truck simply
            // never touches them (TRD §5.3's graceful degradation).
            $table->boolean('gps_tracking_active')->default(false);
            $table->enum('gps_signal_status', ['ok', 'lost', 'not_applicable'])->default('not_applicable');

            $table->text('cancelled_reason')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index('status');
            $table->index('customer_id');
            $table->index('assigned_company_id');
            $table->index(['status', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('jobs');
    }
};
