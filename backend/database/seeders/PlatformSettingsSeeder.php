<?php

namespace Database\Seeders;

use App\Models\PlatformSetting;
use Illuminate\Database\Seeder;

/**
 * Seeds only the values the docs actually specify concrete numbers for
 * (PRD §7.4, §7.8's bid/post quotas). Commission rate, hold threshold, and
 * Featured pricing (Phases 7-8) are deliberately NOT seeded here — those
 * are real business decisions nobody has made yet, not values to guess at
 * just because the table can hold them.
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
        ];

        foreach ($defaults as $key => $value) {
            PlatformSetting::firstOrCreate(['key' => $key], ['value' => $value]);
        }
    }
}
