<?php

namespace Database\Factories;

use App\Models\Payment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Payment>
 */
class PaymentFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'purpose' => 'featured_customer',
            'amount' => fake()->randomFloat(2, 5000, 500000),
            'mobile_money_provider' => fake()->randomElement(['mpesa', 'tigopesa', 'airtelmoney']),
            'gateway_reference' => (string) Str::uuid(),
            'status' => 'initiated',
        ];
    }

    public function pendingConfirmation(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'pending_confirmation']);
    }

    public function succeeded(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'succeeded']);
    }

    public function failed(): static
    {
        return $this->state(fn (array $attributes) => ['status' => 'failed']);
    }
}
