<?php

namespace Database\Factories;

use App\Models\Job;
use App\Models\JobLocationSnapshot;
use App\Models\Truck;
use App\Services\Geo\GeoPoint;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<JobLocationSnapshot>
 */
class JobLocationSnapshotFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'job_id' => Job::factory(),
            'truck_id' => Truck::factory(),
            'recorded_at' => now(),
        ];
    }

    /**
     * `location` isn't fillable (see the model's docblock — it's a raw
     * PostGIS expression), so it can't be set through definition()'s
     * mass-assigned array; set directly via setAttribute() afterward,
     * the same way JobLocationSnapshot::record() does it.
     */
    public function configure(): static
    {
        return $this->afterMaking(function (JobLocationSnapshot $snapshot) {
            $point = new GeoPoint(lat: -6.79 + fake()->randomFloat(3, -0.1, 0.1), lng: 39.21 + fake()->randomFloat(3, -0.1, 0.1));
            $snapshot->setAttribute('location', $point->toInsertExpression());
        });
    }
}
