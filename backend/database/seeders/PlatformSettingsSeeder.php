<?php

namespace Database\Seeders;

use App\Models\PlatformSetting;
use Illuminate\Database\Seeder;

/**
 * Seeds only the values the docs actually specify concrete numbers for,
 * or that a phase's own deliverable requires a working default for.
 *
 * company_featured_price/customer_featured_price/featured_duration_days
 * are the same kind of placeholder for Phase 8: no number exists in the
 * docs for any of these, but "a company or customer can purchase Featured"
 * (the phase's own deliverable) needs a real price and a real duration to
 * actually charge and expire against.
 */
class PlatformSettingsSeeder extends Seeder
{
    public function run(): void
    {
        $defaults = [
            // Cargo Motives Plus has no bid/post quota at all — see
            // BidQuotaService/JobPostQuotaService's own UNLIMITED bypass —
            // so only the standard-tier settings remain configurable here.
            'standard_bid_quota' => '10',
            'standard_bid_window_hours' => '24',
            'standard_customer_post_quota' => '10',
            'company_featured_price' => '5000',
            'customer_featured_price' => '5000',
            'featured_duration_days' => '30',
        ];

        foreach ($defaults as $key => $value) {
            PlatformSetting::firstOrCreate(['key' => $key], ['value' => $value]);
        }
    }
}
