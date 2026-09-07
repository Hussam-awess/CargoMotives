<?php

namespace Tests\Feature\Admin;

use App\Livewire\Admin\Disputes\Index;
use App\Livewire\Admin\Disputes\Show;
use App\Models\Dispute;
use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class DisputesTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_index_defaults_to_open_disputes(): void
    {
        $admin = User::factory()->admin()->create();
        $open = Dispute::factory()->create(['reason' => 'Container was damaged on arrival.']);
        $resolved = Dispute::factory()->resolved()->create(['reason' => 'Already sorted out directly.']);

        Livewire::actingAs($admin)->test(Index::class)
            ->assertSee('Container was damaged')
            ->assertDontSee('Already sorted out');
    }

    public function test_admin_can_mark_a_dispute_under_review(): void
    {
        $admin = User::factory()->admin()->create();
        $dispute = Dispute::factory()->create();

        Livewire::actingAs($admin)->test(Show::class, ['dispute' => $dispute])->call('markUnderReview');

        $this->assertSame('under_review', $dispute->fresh()->status);
    }

    public function test_admin_can_resolve_a_dispute_with_a_note(): void
    {
        $admin = User::factory()->admin()->create();
        $dispute = Dispute::factory()->create();

        Livewire::actingAs($admin)->test(Show::class, ['dispute' => $dispute])
            ->set('resolutionNote', 'Refund issued to the customer via the company.')
            ->call('resolve');

        $dispute->refresh();
        $this->assertSame('resolved', $dispute->status);
        $this->assertSame('Refund issued to the customer via the company.', $dispute->resolution_note);
        $this->assertSame($admin->id, $dispute->resolved_by_admin_id);
        $this->assertNotNull($dispute->resolved_at);
        $this->assertDatabaseHas('activity_logs', ['action' => 'dispute_resolved', 'subject_id' => $dispute->id]);
    }

    public function test_resolving_without_a_note_fails_validation(): void
    {
        $admin = User::factory()->admin()->create();
        $dispute = Dispute::factory()->create();

        Livewire::actingAs($admin)->test(Show::class, ['dispute' => $dispute])
            ->set('resolutionNote', '')
            ->call('resolve')
            ->assertHasErrors('resolutionNote');

        $this->assertSame('open', $dispute->fresh()->status);
    }

    public function test_the_show_page_surfaces_gps_history_as_evidence(): void
    {
        $admin = User::factory()->admin()->create();
        $job = Job::factory()->create();
        $dispute = Dispute::factory()->create(['job_id' => $job->id]);

        Livewire::actingAs($admin)->test(Show::class, ['dispute' => $dispute])
            ->assertSee('No GPS history was recorded for this job.');
    }
}
