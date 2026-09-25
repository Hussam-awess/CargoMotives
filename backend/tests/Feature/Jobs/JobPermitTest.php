<?php

namespace Tests\Feature\Jobs;

use App\Models\Job;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class JobPermitTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_customer_can_upload_a_pickup_permit(): void
    {
        Storage::fake('local');
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/pickup-permit", [
            'document' => UploadedFile::fake()->create('permit.pdf', 100, 'application/pdf'),
        ]);

        $response->assertOk();
        $this->assertNotNull($response->json('data.pickup_permit_url'));
        $this->assertNotNull($response->json('data.pickup_permit_uploaded_at'));
        $this->assertNull($response->json('data.dropoff_permit_url'));
        $this->assertNotNull($job->fresh()->pickup_permit_path);
    }

    public function test_the_customer_can_upload_a_dropoff_permit(): void
    {
        Storage::fake('local');
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/dropoff-permit", [
            'document' => UploadedFile::fake()->create('permit.jpg', 100, 'image/jpeg'),
        ]);

        $response->assertOk();
        $this->assertNotNull($response->json('data.dropoff_permit_url'));
        $this->assertNotNull($response->json('data.dropoff_permit_uploaded_at'));
        $this->assertNotNull($job->fresh()->dropoff_permit_path);
    }

    public function test_uploading_a_permit_replaces_a_previous_one(): void
    {
        Storage::fake('local');
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'dropoff_permit_path' => 'jobs/permits/old.pdf']);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/dropoff-permit", [
            'document' => UploadedFile::fake()->create('new-permit.pdf', 100, 'application/pdf'),
        ])->assertOk();

        $this->assertNotSame('jobs/permits/old.pdf', $job->fresh()->dropoff_permit_path);
    }

    public function test_a_customer_cannot_upload_a_permit_to_another_customers_job(): void
    {
        Storage::fake('local');
        $customer = User::factory()->create();
        $job = Job::factory()->create(); // owned by a different customer

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/pickup-permit", [
            'document' => UploadedFile::fake()->create('permit.pdf', 100, 'application/pdf'),
        ])->assertNotFound();

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/dropoff-permit", [
            'document' => UploadedFile::fake()->create('permit.pdf', 100, 'application/pdf'),
        ])->assertNotFound();
    }

    public function test_uploading_a_permit_requires_a_document(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/pickup-permit", [])
            ->assertUnprocessable()->assertJsonValidationErrors(['document']);
    }

    public function test_uploading_a_permit_rejects_an_unsupported_file_type(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id]);

        $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/dropoff-permit", [
            'document' => UploadedFile::fake()->create('permit.exe', 100, 'application/octet-stream'),
        ])->assertUnprocessable()->assertJsonValidationErrors(['document']);
    }
}
