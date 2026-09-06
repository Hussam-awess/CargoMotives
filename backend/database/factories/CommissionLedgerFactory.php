<?php

namespace Database\Factories;

use App\Models\CommissionLedger;
use App\Models\TransporterCompany;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<CommissionLedger>
 */
class CommissionLedgerFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $amount = fake()->randomFloat(2, 5000, 300000);

        return [
            'transporter_company_id' => TransporterCompany::factory(),
            'entry_type' => 'charge',
            'amount' => $amount,
            'balance_after' => $amount,
        ];
    }
}
