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
            'standard_bid_quota' => '5',
            'standard_bid_window_hours' => '24',
            'featured_bid_quota' => '10',
            'featured_bid_window_hours' => '15',
            'standard_customer_post_quota' => '5',
            'featured_customer_post_quota' => '10',
            'company_featured_price' => '50000',
            'customer_featured_price' => '20000',
            'featured_duration_days' => '30',
        ];

        foreach ($defaults as $key => $value) {
            PlatformSetting::firstOrCreate(['key' => $key], ['value' => $value]);
        }
    }
}
