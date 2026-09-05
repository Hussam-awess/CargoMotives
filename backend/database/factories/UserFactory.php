<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'account_type' => 'customer',
            // +255 7XXXXXXXX — a plausible Tanzanian mobile number shape;
            // unique() so factory-created users never collide on the
            // phone_number unique constraint.
            'phone_number' => '+255'.fake()->unique()->numerify('7########'),
            'email' => fake()->unique()->safeEmail(),
            'full_name' => fake()->name(),
            'language_preference' => 'sw',
        ];
    }

    /**
     * Indicate the user is a transporter company's representative account
     * (the transporter_companies row itself is created separately — Phase 2).
     */
    public function transporterCompany(): static
    {
        return $this->state(fn (array $attributes) => [
            'account_type' => 'transporter_company',
            'full_name' => null,
        ]);
    }

    public function withPassword(string $password = 'password'): static
    {
        return $this->state(fn (array $attributes) => [
            'password_hash' => Hash::make($password),
        ]);
    }

    /**
     * An Admin account (email+password login — AdminAuthController, not
     * the Customer/Company phone+OTP flow).
     */
    public function admin(string $password = 'password'): static
    {
        return $this->state(fn (array $attributes) => [
            'account_type' => 'admin',
            'password_hash' => Hash::make($password),
        ]);
    }
}
