<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Jobs\Index;
use App\Livewire\Admin\Jobs\Show;
use App\Models\Bid;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class JobsTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_index_filters_by_status(): void
    {
        $admin = User::factory()->admin()->create();
        $open = Job::factory()->create(['status' => 'open', 'pickup_address' => 'Dar Port', 'dropoff_address' => 'Arusha']);
        $completed = Job::factory()->create(['status' => 'completed', 'pickup_address' => 'Mwanza', 'dropoff_address' => 'Dodoma']);

        Livewire::actingAs($admin)->test(Index::class)
            ->assertSee('#'.$open->id)->assertSee('#'.$completed->id)
            ->set('status', 'completed')
            ->assertDontSee('#'.$open->id)->assertSee('#'.$completed->id);
    }

    public function test_the_show_page_lists_bids_and_the_status_change_timeline(): void
    {
        $admin = User::factory()->admin()->create();
        $job = Job::factory()->create(['status' => 'open']);
        $company = TransporterCompany::factory()->approved()->create(['company_name' => 'Kilimanjaro Transport']);
        Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $company->id, 'price' => 150000]);

        // Triggers JobObserver's job_status_changed log entry, exactly
        // the way a real assignment/delivery flow would.
        $job->update(['status' => 'assigned', 'assigned_company_id' => $company->id]);

        Livewire::actingAs($admin)->test(Show::class, ['job' => $job])
            ->assertSee('Kilimanjaro Transport')
            ->assertSee('Job Status Changed')
            ->assertSee('Bid Placed');
    }
}
