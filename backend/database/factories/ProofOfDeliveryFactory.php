<?php

namespace Database\Factories;

use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use App\Models\ProofOfDelivery;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProofOfDelivery>
 */
class ProofOfDeliveryFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'job_id' => Job::factory(),
            'driver_id' => Driver::factory(),
            'driver_link_id' => DriverLink::factory(),
            'photo_urls' => ['proof-of-delivery/fake-photo.jpg'],
            'recipient_name' => fake()->name(),
            'notes' => fake()->optional()->sentence(),
        ];
    }
}
