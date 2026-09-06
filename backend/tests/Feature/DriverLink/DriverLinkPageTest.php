<?php

namespace Tests\Feature\DriverLink;

use App\Models\Driver;
use App\Models\DriverLink;
use App\Models\Job;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * The no-login, server-rendered Driver Link page (AppFlow §4). These hit
 * plain web routes (routes/web.php), not the JSON API — a token in the
 * URL is the entire authorization, so there's no actingAs() anywhere here.
 */
class DriverLinkPageTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_valid_link_shows_the_job_summary_and_next_action(): void
    {
        $job = Job::factory()->assigned()->create(['pickup_address' => 'Kariakoo, Dar es Salaam']);
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $response = $this->get("/driver-link/{$link->token}");

        $response->assertOk()
            ->assertSee('Kariakoo, Dar es Salaam')
            ->assertSee('Mark as En Route to Pickup')
            ->assertSee('Submit Proof of Delivery');
    }

    public function test_an_unknown_token_shows_a_not_found_page(): void
    {
        $this->get('/driver-link/not-a-real-token')
            ->assertOk()
            ->assertSee("We couldn't find this link", false);
    }

    public function test_an_expired_link_shows_an_expired_page(): void
    {
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->expired()->create(['job_id' => $job->id]);

        $this->get("/driver-link/{$link->token}")
            ->assertOk()
            ->assertSee('This link has expired');
    }

    public function test_an_already_used_link_shows_the_submitted_confirmation(): void
    {
        $job = Job::factory()->create(['status' => 'delivered']);
        $link = DriverLink::factory()->used()->create(['job_id' => $job->id]);

        $this->get("/driver-link/{$link->token}")
            ->assertOk()
            ->assertSee('Delivered — thank you!');
    }

    public function test_the_driver_can_advance_the_job_status_forward_only(): void
    {
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertRedirect();
        $this->assertSame('en_route_pickup', $job->fresh()->status);

        // Backward move is rejected.
        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertSessionHasErrors('status');
        $this->assertSame('en_route_pickup', $job->fresh()->status);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'in_transit'])
            ->assertRedirect();
        $this->assertSame('in_transit', $job->fresh()->status);
    }

    public function test_status_updates_are_rejected_once_the_link_has_expired(): void
    {
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->expired()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/status", ['status' => 'en_route_pickup'])
            ->assertStatus(410);
        $this->assertSame('assigned', $job->fresh()->status);
    }

    public function test_submitting_proof_of_delivery_marks_the_job_delivered_and_the_link_used(): void
    {
        Storage::fake('local');
        $job = Job::factory()->assigned()->create();
        $driver = Driver::factory()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id, 'driver_id' => $driver->id]);

        $response = $this->post("/driver-link/{$link->token}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
            'recipient_name' => 'Asha Mwinyi',
            'notes' => 'Left at the front desk.',
        ]);

        $response->assertRedirect("/driver-link/{$link->token}");

        $job->refresh();
        $link->refresh();
        $this->assertSame('delivered', $job->status);
        $this->assertSame('used', $link->status);
        $this->assertNotNull($link->used_at);
        $this->assertDatabaseHas('proof_of_deliveries', [
            'job_id' => $job->id,
            'driver_id' => $driver->id,
            'driver_link_id' => $link->id,
            'recipient_name' => 'Asha Mwinyi',
        ]);
    }

    public function test_proof_of_delivery_requires_at_least_one_photo(): void
    {
        $job = Job::factory()->assigned()->create();
        $link = DriverLink::factory()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/proof-of-delivery", ['recipient_name' => 'Asha Mwinyi'])
            ->assertSessionHasErrors('photos');
        $this->assertSame('assigned', $job->fresh()->status);
    }

    public function test_a_used_links_proof_of_delivery_route_cannot_be_submitted_again(): void
    {
        Storage::fake('local');
        $job = Job::factory()->create(['status' => 'delivered']);
        $link = DriverLink::factory()->used()->create(['job_id' => $job->id]);

        $this->post("/driver-link/{$link->token}/proof-of-delivery", [
            'photos' => [UploadedFile::fake()->create('proof.jpg', 200, 'image/jpeg')],
        ])->assertStatus(410);
    }
}
