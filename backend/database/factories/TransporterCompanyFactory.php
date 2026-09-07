<?php

namespace Database\Factories;

use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<TransporterCompany>
 */
class TransporterCompanyFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'owner_user_id' => User::factory()->transporterCompany(),
            'company_name' => fake()->company(),
            'registration_number' => fake()->unique()->numerify('REG-######'),
            'tin' => fake()->unique()->numerify('TIN-#########'),
            'physical_address' => fake()->address(),
            'company_phone' => '+255'.fake()->numerify('7########'),
            'company_email' => fake()->unique()->companyEmail(),
            'documents' => [
                'registration_certificate' => 'companies/documents/fake-registration-certificate.pdf',
                'tin_certificate' => 'companies/documents/fake-tin-certificate.pdf',
            ],
            'rep_full_name' => fake()->name(),
            'rep_position' => 'Operations Manager',
            'rep_national_id_number' => fake()->unique()->numerify('NIDA-##############'),
            'rep_id_document_url' => 'companies/rep-documents/fake-id.pdf',
            'rep_selfie_url' => 'companies/rep-selfies/fake-selfie.jpg',
            'rep_phone_verified' => true,
            'rep_email_verified' => false,
            'verification_status' => 'pending',
        ];
    }

    public function approved(): static
    {
        return $this->state(fn (array $attributes) => [
            'verification_status' => 'approved',
            'verified_at' => now(),
        ]);
    }

    public function flaggedDuplicate(): static
    {
        return $this->state(fn (array $attributes) => [
            'verification_status' => 'flagged_duplicate',
        ]);
    }

    public function rejected(string $reason = 'Documents were unreadable.'): static
    {
        return $this->state(fn (array $attributes) => [
            'verification_status' => 'rejected',
            'verification_rejected_reason' => $reason,
        ]);
    }
}
