<?php

namespace Database\Factories;

use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<DriverLink>
 */
class DriverLinkFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'job_id' => Job::factory(),
            'driver_id' => Driver::factory(),
            'token' => Str::random(48),
            'status' => 'active',
            'expires_at' => now()->addDays(14),
        ];
    }

    public function used(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'used', 'used_at' => now()]);
    }

    public function expired(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'expired', 'expires_at' => now()->subDay()]);
    }
}
