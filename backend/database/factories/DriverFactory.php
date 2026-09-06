<?php

namespace Database\Factories;

use App\Models\Driver;
use App\Models\TransporterCompany;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Driver>
 */
class DriverFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'transporter_company_id' => TransporterCompany::factory(),
            'full_name' => fake()->name(),
            'phone_number' => '+255'.fake()->unique()->numerify('7########'),
            'license_number' => fake()->bothify('DL-#####'),
            'is_active' => true,
        ];
    }
}
