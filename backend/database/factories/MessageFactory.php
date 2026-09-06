<?php

namespace Database\Factories;

use App\Models\Job;
use App\Models\Message;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Message>
 */
class MessageFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'job_id' => Job::factory(),
            'sender_user_id' => User::factory(),
            'body' => fake()->sentence(),
        ];
    }
}
