<?php

namespace Database\Factories;

use App\Models\GpsConnection;
use App\Models\TransporterCompany;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<GpsConnection>
 */
class GpsConnectionFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'transporter_company_id' => TransporterCompany::factory(),
            'provider' => 'wialon',
            'access_token' => Str::random(32),
            'status' => 'connected',
            'connected_at' => now(),
        ];
    }
}
