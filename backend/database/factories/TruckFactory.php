<?php

namespace Database\Factories;

use App\Models\TransporterCompany;
use App\Models\Truck;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Truck>
 */
class TruckFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'transporter_company_id' => TransporterCompany::factory(),
            'registration_number' => strtoupper(fake()->bothify('T ###??')),
            'make_model' => fake()->randomElement(['Isuzu FRR', 'Mitsubishi Fuso', 'Scania G410', 'Man TGS']),
            'vehicle_type' => fake()->randomElement(['Flatbed', 'Box Truck', 'Container Trailer', 'Tanker']),
            'capacity_tons' => fake()->randomFloat(2, 3, 30),
            'documents' => [
                'photos' => ['trucks/photos/fake-photo.jpg'],
                'registration_card' => 'trucks/documents/fake-reg-card.pdf',
                'insurance' => 'trucks/documents/fake-insurance.pdf',
            ],
            'verification_status' => 'pending',
        ];
    }

    public function approved(): static
    {
        return $this->state(fn (array $attributes) => ['verification_status' => 'approved']);
    }

    public function rejected(string $reason = 'Registration card photo is unreadable.'): static
    {
        return $this->state(fn (array $attributes) => [
            'verification_status' => 'rejected',
            'verification_rejected_reason' => $reason,
        ]);
    }
}
