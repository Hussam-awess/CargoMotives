<?php

namespace Database\Factories;

use App\Models\Job;
use App\Models\User;
use App\Services\Geo\GeoPoint;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Job>
 */
class JobFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        // Roughly within Dar es Salaam, jittered — real coordinates so any
        // future PostGIS distance query against factory data behaves
        // sensibly, not just placeholder zeros.
        $pickup = new GeoPoint(lat: -6.79 + fake()->randomFloat(3, -0.1, 0.1), lng: 39.21 + fake()->randomFloat(3, -0.1, 0.1));
        $dropoff = new GeoPoint(lat: -6.79 + fake()->randomFloat(3, -0.1, 0.1), lng: 39.21 + fake()->randomFloat(3, -0.1, 0.1));

        return [
            'customer_id' => User::factory(),
            'status' => 'open',
            'pickup_address' => fake()->streetAddress().', Dar es Salaam',
            'pickup_location' => $pickup->toInsertExpression(),
            'dropoff_address' => fake()->streetAddress().', Dar es Salaam',
            'dropoff_location' => $dropoff->toInsertExpression(),
            'container_type' => fake()->randomElement(['Dry Van', 'Reefer', 'Open Top']),
            'container_size' => fake()->randomElement(['20ft', '40ft']),
            'approx_weight_tons' => fake()->randomFloat(2, 1, 25),
            'preferred_pickup_window_start' => now()->addDay(),
        ];
    }

    public function assigned(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'assigned']);
    }

    public function cancelled(string $reason = 'Customer no longer needs this shipment.'): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'cancelled',
            'cancelled_reason' => $reason,
        ]);
    }
}
