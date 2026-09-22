<?php

namespace Tests\Feature\Messaging;

use App\Models\Job;
use App\Models\Message;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * A job's message thread (Backend Schema §2.15). Plain REST, no
 * WebSocket — see MessageController's docblock for why.
 */
class MessageControllerTest extends TestCase
{
    use RefreshDatabase;

    private function assignedJobWithParticipants(): array
    {
        $customer = User::factory()->create();
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $company->id]);

        return [$job, $customer, $companyOwner];
    }

    public function test_the_customer_can_send_a_message_to_the_assigned_company(): void
    {
        [$job, $customer] = $this->assignedJobWithParticipants();

        $response = $this->actingAs($customer)->postJson("/api/jobs/{$job->id}/messages", ['body' => 'When will you arrive?']);

        $response->assertCreated()->assertJsonPath('data.body', 'When will you arrive?')->assertJsonPath('data.is_mine', true);
    }

    public function test_the_assigned_companys_owner_can_reply(): void
    {
        [$job, , $companyOwner] = $this->assignedJobWithParticipants();

        $this->actingAs($companyOwner)
            ->postJson("/api/jobs/{$job->id}/messages", ['body' => 'On our way.'])
            ->assertCreated()
            ->assertJsonPath('data.is_mine', true);
    }

    public function test_cannot_message_a_job_with_no_assigned_company_yet(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/messages", ['body' => 'Hello?'])
            ->assertUnprocessable();
    }

    public function test_an_unrelated_user_cannot_read_or_send_messages(): void
    {
        [$job] = $this->assignedJobWithParticipants();
        $stranger = User::factory()->create();

        $this->actingAs($stranger)->getJson("/api/jobs/{$job->id}/messages")->assertNotFound();
        $this->actingAs($stranger)->postJson("/api/jobs/{$job->id}/messages", ['body' => 'hi'])->assertNotFound();
    }

    public function test_messages_are_returned_in_chronological_order(): void
    {
        [$job, $customer, $companyOwner] = $this->assignedJobWithParticipants();
        $first = Message::factory()->create(['job_id' => $job->id, 'sender_user_id' => $customer->id, 'created_at' => now()->subMinutes(5)]);
        $second = Message::factory()->create(['job_id' => $job->id, 'sender_user_id' => $companyOwner->id, 'created_at' => now()]);

        $response = $this->actingAs($customer)->getJson("/api/jobs/{$job->id}/messages");

        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertSame([$first->id, $second->id], $ids);
    }

    public function test_opening_the_thread_marks_the_other_partys_messages_read(): void
    {
        [$job, $customer, $companyOwner] = $this->assignedJobWithParticipants();
        $fromCompany = Message::factory()->create(['job_id' => $job->id, 'sender_user_id' => $companyOwner->id]);
        $fromCustomer = Message::factory()->create(['job_id' => $job->id, 'sender_user_id' => $customer->id]);

        $this->actingAs($customer)->getJson("/api/jobs/{$job->id}/messages")->assertOk();

        // The customer opening the thread marks the *company's* message
        // read (it wasn't theirs) but leaves their own message untouched.
        $this->assertNotNull($fromCompany->fresh()->read_at);
        $this->assertNull($fromCustomer->fresh()->read_at);
    }

    public function test_a_message_from_a_plus_company_owner_is_flagged_featured(): void
    {
        $customer = User::factory()->create();
        $companyOwner = User::factory()->transporterCompany()->create();
        $company = TransporterCompany::factory()->approved()->for($companyOwner, 'owner')->create(['is_featured' => true]);
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $company->id]);

        $this->actingAs($companyOwner)
            ->postJson("/api/jobs/{$job->id}/messages", ['body' => 'On our way.'])
            ->assertCreated()
            ->assertJsonPath('data.sender_is_featured', true);

        $this->actingAs($customer)
            ->getJson("/api/jobs/{$job->id}/messages")
            ->assertOk()
            ->assertJsonPath('data.0.sender_is_featured', true);
    }

    public function test_a_message_from_a_plus_customer_is_flagged_featured(): void
    {
        $customer = User::factory()->create(['is_featured' => true]);
        [$job, , $companyOwner] = $this->assignedJobWithParticipants();
        $job->update(['customer_id' => $customer->id]);

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/messages", ['body' => 'Please hurry.'])
            ->assertCreated()
            ->assertJsonPath('data.sender_is_featured', true);

        $this->actingAs($companyOwner)
            ->getJson("/api/jobs/{$job->id}/messages")
            ->assertOk()
            ->assertJsonPath('data.0.sender_is_featured', true);
    }

    public function test_a_message_from_a_non_plus_sender_is_not_flagged_featured(): void
    {
        [$job, $customer] = $this->assignedJobWithParticipants();

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/messages", ['body' => 'Hello.'])
            ->assertCreated()
            ->assertJsonPath('data.sender_is_featured', false);
    }

    public function test_a_message_body_cannot_be_empty(): void
    {
        [$job, $customer] = $this->assignedJobWithParticipants();

        $this->actingAs($customer)
            ->postJson("/api/jobs/{$job->id}/messages", ['body' => ''])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('body');
    }
}
