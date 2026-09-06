<?php

namespace Database\Seeders;

use App\Models\PlatformSetting;
use Illuminate\Database\Seeder;

/**
 * Seeds only the values the docs actually specify concrete numbers for,
 * or that a phase's own deliverable requires a working default for.
 * Featured pricing (Phase 8) is still deliberately NOT seeded — nothing
 * in this codebase reads it yet, and it's a real business decision nobody
 * has made.
 *
 * commission_rate_default=30 mirrors the TRD's fixed "30% of agreed
 * price" (§6) — seeded as the *default*, not hardcoded in code, so an
 * Admin can adjust it later without a deploy (Phase 9's settings form).
 * commission_hold_threshold=500000 (TZS) has no source-of-truth number in
 * the docs; picked as a reasonable placeholder since Phase 7's own
 * deliverable ("crossing the threshold correctly blocks new bids")
 * requires *some* working value to test against — adjustable the same way.
 */
class PlatformSettingsSeeder extends Seeder
{
    public function run(): void
    {
        $defaults = [
            'standard_bid_quota' => '5',
            'standard_bid_window_hours' => '24',
            'featured_bid_quota' => '10',
            'featured_bid_window_hours' => '15',
            'standard_customer_post_quota' => '5',
            'featured_customer_post_quota' => '10',
            'commission_rate_default' => '30',
            'commission_hold_threshold' => '500000',
        ];

        foreach ($defaults as $key => $value) {
            PlatformSetting::firstOrCreate(['key' => $key], ['value' => $value]);
        }
    }
}
