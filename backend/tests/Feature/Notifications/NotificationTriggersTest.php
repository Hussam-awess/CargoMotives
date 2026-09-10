<?php

namespace Tests\Feature\Notifications;

use App\Models\Bid;
use App\Models\Job;
use App\Models\Message;
use App\Models\Notification;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use App\Services\Company\CompanyVerificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Every event in AppFlow §6's Notification Trigger Map that this app can
 * actually fire from a mobile-app-driven action (the Driver Link's SMS
 * step and Admin's own in-app dispute dashboard note are out of scope —
 * neither goes through App\Services\Notifications\NotificationService).
 * Each test only asserts a `notifications` row landed for the right
 * recipient with the right type — the underlying state change itself
 * (approval, bid acceptance, etc.) is already covered by that feature's
 * own tests.
 */
class NotificationTriggersTest extends TestCase
{
    use RefreshDatabase;

    public function test_company_approval_notifies_the_owner(): void
    {
        $company = TransporterCompany::factory()->create();

        app(CompanyVerificationService::class)->approve($company);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'company_approved',
        ]);
    }

    public function test_company_rejection_notifies_the_owner(): void
    {
        $company = TransporterCompany::factory()->create();

        $company->update(['verification_status' => 'rejected', 'verification_rejected_reason' => 'Bad documents.']);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'company_rejected',
        ]);
    }

    public function test_a_flagged_duplicate_transition_does_not_notify(): void
    {
        $company = TransporterCompany::factory()->create();

        $company->update(['verification_status' => 'flagged_duplicate']);

        $this->assertDatabaseMissing('notifications', ['user_id' => $company->owner_user_id]);
    }

    public function test_truck_approval_notifies_the_companys_owner(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $truck = Truck::factory()->create(['transporter_company_id' => $company->id]);

        $truck->update(['verification_status' => 'approved']);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'truck_approved',
        ]);
    }

    public function test_truck_rejection_notifies_the_companys_owner(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $truck = Truck::factory()->create(['transporter_company_id' => $company->id]);

        $truck->update(['verification_status' => 'rejected', 'verification_rejected_reason' => 'Unreadable photo.']);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'truck_rejected',
        ]);
    }

    public function test_placing_a_bid_notifies_the_jobs_customer(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);

        Bid::factory()->create(['job_id' => $job->id]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $customer->id,
            'type' => 'new_bid',
            'related_job_id' => $job->id,
        ]);
    }

    public function test_accepting_a_bid_notifies_that_bid_company_and_rejects_notify_the_others(): void
    {
        $customer = User::factory()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'status' => 'open']);
        $winningCompany = TransporterCompany::factory()->approved()->create();
        $losingCompany = TransporterCompany::factory()->approved()->create();
        $winningBid = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $winningCompany->id]);
        $losingBid = Bid::factory()->create(['job_id' => $job->id, 'transporter_company_id' => $losingCompany->id]);

        $this->actingAs($customer)->postJson("/api/bids/{$winningBid->id}/accept")->assertOk();

        $this->assertDatabaseHas('notifications', [
            'user_id' => $winningCompany->owner_user_id,
            'type' => 'bid_accepted',
        ]);
        $this->assertDatabaseHas('notifications', [
            'user_id' => $losingCompany->owner_user_id,
            'type' => 'bid_not_selected',
        ]);
    }

    public function test_gps_signal_lost_notifies_customer_and_company(): void
    {
        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        $job = Job::factory()->create([
            'customer_id' => $customer->id,
            'assigned_company_id' => $company->id,
            'gps_tracking_active' => true,
            'gps_signal_status' => 'ok',
        ]);

        $job->update(['gps_signal_status' => 'lost']);

        $this->assertDatabaseHas('notifications', ['user_id' => $customer->id, 'type' => 'gps_signal_lost']);
        $this->assertDatabaseHas('notifications', ['user_id' => $company->owner_user_id, 'type' => 'gps_signal_lost']);
    }

    public function test_gps_signal_recovery_does_not_notify(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $job = Job::factory()->create(['assigned_company_id' => $company->id, 'gps_signal_status' => 'lost']);

        $job->update(['gps_signal_status' => 'ok']);

        $this->assertDatabaseMissing('notifications', ['type' => 'gps_signal_lost']);
    }

    public function test_job_delivered_notifies_customer_and_company(): void
    {
        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $company->id, 'status' => 'in_transit']);

        $job->update(['status' => 'delivered']);

        $this->assertDatabaseHas('notifications', ['user_id' => $customer->id, 'type' => 'proof_of_delivery_submitted']);
        $this->assertDatabaseHas('notifications', ['user_id' => $company->owner_user_id, 'type' => 'proof_of_delivery_submitted']);
    }

    public function test_job_completed_notifies_the_company(): void
    {
        $company = TransporterCompany::factory()->approved()->create();
        $job = Job::factory()->create(['assigned_company_id' => $company->id, 'status' => 'delivered']);

        $job->update(['status' => 'completed']);

        $this->assertDatabaseHas('notifications', ['user_id' => $company->owner_user_id, 'type' => 'delivery_confirmed']);
    }

    public function test_a_new_message_from_the_customer_notifies_the_company_owner(): void
    {
        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $company->id]);

        Message::factory()->create(['job_id' => $job->id, 'sender_user_id' => $customer->id]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $company->owner_user_id,
            'type' => 'new_message',
        ]);
    }

    public function test_a_new_message_from_the_company_notifies_the_customer(): void
    {
        $customer = User::factory()->create();
        $company = TransporterCompany::factory()->approved()->create();
        $job = Job::factory()->create(['customer_id' => $customer->id, 'assigned_company_id' => $company->id]);

        Message::factory()->create(['job_id' => $job->id, 'sender_user_id' => $company->owner_user_id]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $customer->id,
            'type' => 'new_message',
        ]);
    }

    public function test_a_notification_never_blocks_the_underlying_action_even_with_the_firebase_driver_misconfigured(): void
    {
        // PUSH_DRIVER=firebase with no real credentials must degrade
        // exactly like Selcom/Wialon's own unreachable-provider cases —
        // the in-app notification (and the state change that caused it)
        // must never fail because the push attempt did.
        config(['fcm.default' => 'firebase', 'fcm.credentials_path' => null]);

        $company = TransporterCompany::factory()->create();

        app(CompanyVerificationService::class)->approve($company);

        $this->assertSame('approved', $company->fresh()->verification_status);
        $this->assertDatabaseHas('notifications', ['user_id' => $company->owner_user_id, 'type' => 'company_approved']);
        $this->assertDatabaseHas('notifications', ['user_id' => $company->owner_user_id, 'sent_via_fcm' => false]);
    }
}
