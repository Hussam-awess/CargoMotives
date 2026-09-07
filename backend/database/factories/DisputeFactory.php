<?php

namespace Database\Factories;

use App\Models\Dispute;
use App\Models\Job;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Dispute>
 */
class DisputeFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'job_id' => Job::factory(),
            'raised_by_user_id' => User::factory(),
            'reason' => fake()->sentence(),
            'status' => 'open',
        ];
    }

    public function resolved(): static
    {
        return $this->state(fn () => [
            'status' => 'resolved',
            'resolution_note' => fake()->sentence(),
            'resolved_by_admin_id' => User::factory()->state(['account_type' => 'admin']),
            'resolved_at' => now(),
        ]);
    }
}
