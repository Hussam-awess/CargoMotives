<?php

namespace Database\Factories;

use App\Models\Bid;
use App\Models\Job;
use App\Models\TransporterCompany;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Bid>
 */
class BidFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'job_id' => Job::factory(),
            'transporter_company_id' => TransporterCompany::factory()->approved(),
            'price' => fake()->randomFloat(2, 200000, 2000000),
            'estimated_pickup_time' => now()->addHours(fake()->numberBetween(2, 48)),
            'note' => fake()->optional()->sentence(),
            'status' => 'pending',
        ];
    }

    public function accepted(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'accepted']);
    }

    public function rejected(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'rejected']);
    }

    public function withdrawn(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'withdrawn']);
    }
}
