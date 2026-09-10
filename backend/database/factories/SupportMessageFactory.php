<?php

namespace Database\Factories;

use App\Models\SupportMessage;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<SupportMessage>
 */
class SupportMessageFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'author' => 'user',
            'admin_id' => null,
            'body' => fake()->sentence(),
        ];
    }

    public function fromAdmin(): static
    {
        return $this->state(fn (array $attributes) => ['author' => 'admin', 'admin_id' => User::factory()->admin()]);
    }
}
