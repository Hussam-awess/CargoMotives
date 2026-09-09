<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Phase 13 (user's own explicit field list, restated a second time without
 * a selfie): the representative selfie is dropped from Step 2 entirely,
 * not just made optional in the UI — existing rows keep whatever selfie
 * they already have (nothing is deleted), but new/resubmitted verifications
 * no longer collect or require one. Raw SQL rather than Schema::table(...)
 * ->nullable()->change(), which needs doctrine/dbal — not worth adding as a
 * dependency for one column-nullability change.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE transporter_companies ALTER COLUMN rep_selfie_url DROP NOT NULL');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE transporter_companies ALTER COLUMN rep_selfie_url SET NOT NULL');
    }
};
