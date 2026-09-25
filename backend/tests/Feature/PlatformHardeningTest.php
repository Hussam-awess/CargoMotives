<?php

namespace Tests\Feature;

use App\Jobs\SendSmsAlertJob;
use App\Models\CustomerFollow;
use App\Models\Job;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Models\User;
use App\Services\Notifications\NotificationService;
use App\Support\Pii;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class PlatformHardeningTest extends TestCase
{
    use RefreshDatabase;

    public function test_every_response_carries_security_headers_and_a_request_id(): void
    {
        $response = $this->getJson('/api/health');

        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
        $this->assertNotEmpty($response->headers->get('X-Request-Id'));
    }

    public function test_a_well_formed_client_request_id_is_echoed_back(): void
    {
        $this->getJson('/api/health', ['X-Request-Id' => 'mobile-3f9c2a7b'])
            ->assertHeader('X-Request-Id', 'mobile-3f9c2a7b');
    }

    public function test_a_malformed_client_request_id_is_replaced_not_trusted(): void
    {
        $response = $this->getJson('/legal/terms', ['X-Request-Id' => "bad id\nwith injected log line"]);

        $this->assertNotSame("bad id\nwith injected log line", $response->headers->get('X-Request-Id'));
        $this->assertMatchesRegularExpression('/^[A-Za-z0-9-]{8,64}$/', $response->headers->get('X-Request-Id'));
    }

    public function test_pii_masking_keeps_only_the_last_characters(): void
    {
        $this->assertSame('**********678', Pii::maskPhone('+255712345678'));
        $this->assertSame('a****@example.com', Pii::maskEmail('amina@example.com'));
    }

    public function test_a_shipment_update_is_also_sent_by_sms_when_the_user_opted_in(): void
    {
        Queue::fake();
        $user = User::factory()->create(['notification_preferences' => ['sms_alerts' => true]]);

        app(NotificationService::class)->send($user, 'job_status_changed', 'Shipment update', 'Your cargo was picked up.');

        Queue::assertPushed(SendSmsAlertJob::class);
    }

    public function test_no_sms_is_sent_without_opting_in_or_for_non_shipment_notifications(): void
    {
        Queue::fake();
        $notOptedIn = User::factory()->create();
        $optedIn = User::factory()->create(['notification_preferences' => ['sms_alerts' => true]]);

        app(NotificationService::class)->send($notOptedIn, 'job_status_changed', 'Shipment update', 'Picked up.');
        app(NotificationService::class)->send($optedIn, 'new_message', 'New message', 'Hello');

        Queue::assertNotPushed(SendSmsAlertJob::class);
    }

    public function test_a_company_not_accepting_loads_gets_no_new_job_alerts(): void
    {
        Queue::fake();
        $customer = User::factory()->create();

        $accepting = TransporterCompany::factory()->approved()->create();
        $paused = TransporterCompany::factory()->approved()->create(['accepting_loads' => false]);

        foreach ([$accepting, $paused] as $company) {
            Truck::factory()->create(['transporter_company_id' => $company->id, 'verification_status' => 'approved']);
            CustomerFollow::create(['customer_id' => $customer->id, 'transporter_company_id' => $company->id]);
        }

        Job::factory()->create(['customer_id' => $customer->id]);

        $this->assertDatabaseHas('notifications', ['user_id' => $accepting->owner_user_id, 'type' => 'new_job_posted']);
        $this->assertDatabaseMissing('notifications', ['user_id' => $paused->owner_user_id, 'type' => 'new_job_posted']);
    }

    public function test_a_company_can_pause_accepting_loads_from_settings(): void
    {
        $company = TransporterCompany::factory()->approved()->create();

        $this->actingAs($company->owner)
            ->postJson('/api/company/preferences', ['accepting_loads' => false])
            ->assertOk();

        $this->assertFalse($company->fresh()->accepting_loads);

        $this->actingAs($company->owner)
            ->getJson('/api/company/featured/status')
            ->assertOk()
            ->assertJsonPath('accepting_loads', false);
    }
}
