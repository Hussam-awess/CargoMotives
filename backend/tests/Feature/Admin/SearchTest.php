<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Search\Index;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class SearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_finds_a_customer_by_name(): void
    {
        $admin = User::factory()->admin()->create();
        User::factory()->create(['full_name' => 'Amina Juma']);
        User::factory()->create(['full_name' => 'Someone Else']);

        Livewire::actingAs($admin)->test(Index::class)
            ->set('query', 'Amina')
            ->assertSee('Amina Juma')->assertDontSee('Someone Else');
    }

    public function test_it_finds_a_company_by_registration_number(): void
    {
        $admin = User::factory()->admin()->create();
        TransporterCompany::factory()->create(['company_name' => 'Serengeti Freight', 'registration_number' => 'REG-9876']);
        TransporterCompany::factory()->create(['company_name' => 'Other Co', 'registration_number' => 'REG-0000']);

        Livewire::actingAs($admin)->test(Index::class)
            ->set('query', 'REG-9876')
            ->assertSee('Serengeti Freight')->assertDontSee('Other Co');
    }

    public function test_an_empty_query_shows_no_results_section(): void
    {
        $admin = User::factory()->admin()->create();
        User::factory()->create(['full_name' => 'Amina Juma']);

        Livewire::actingAs($admin)->test(Index::class)->assertDontSee('Amina Juma');
    }
}
