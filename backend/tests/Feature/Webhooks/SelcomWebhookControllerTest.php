<?php

namespace Tests\Feature\Webhooks;

use App\Models\CommissionLedger;
use App\Models\Payment;
use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Selcom's payment-outcome callback (TRD §7). Deliberately computes real
 * signatures against SELCOM_WEBHOOK_SECRET rather than mocking
 * MobileMoneyGateway — this is the one place the app's own security
 * (rejecting a spoofed webhook) and idempotency (never double-crediting a
 * retried delivery) actually have to be proven end to end.
 *
 * Phase 10 audit note: the idempotency check now happens inside a
 * lockForUpdate() transaction specifically to close a TOCTOU race between
 * two genuinely concurrent deliveries for the same reference (see
 * SelcomWebhookController::handle()'s docblock). PHPUnit runs single-
 * process/single-connection, so no test here can actually exercise two
 * overlapping transactions racing each other — the tests below prove the
 * sequential/reordered cases are correct, and the concurrent case relies
 * on the database's own row-lock guarantee, same as
 * CommissionLedgerService's company-row lock (also untested for true
 * concurrency, by the same limitation).
 */
class SelcomWebhookControllerTest extends TestCase
{
    use RefreshDatabase;

    private function signedPost(array $payload): TestResponse
    {
        $body = json_encode($payload);
        $signature = hash_hmac('sha256', $body, config('services.selcom.webhook_secret'));

        return $this->call('POST', '/api/webhooks/selcom', [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_X-Selcom-Signature' => $signature,
        ], $body);
    }

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.selcom.webhook_secret' => 'test-webhook-secret']);
    }

    public function test_a_completed_payment_credits_the_ledger(): void
    {
        $owner = User::factory()->create();
        $company = TransporterCompany::factory()->for($owner, 'owner')->create(['outstanding_balance' => 50000]);
        $payment = Payment::factory()->pendingConfirmation()->create(['user_id' => $owner->id, 'amount' => 20000]);

        $this->signedPost(['order_id' => $payment->gateway_reference, 'payment_status' => 'COMPLETED'])->assertOk();

        $this->assertSame('succeeded', $payment->fresh()->status);
        $this->assertEquals(30000, $company->fresh()->outstanding_balance);
        $this->assertDatabaseHas('commission_ledger', ['payment_id' => $payment->id, 'entry_type' => 'payment']);
    }

    public function test_a_retried_completed_webhook_does_not_double_credit(): void
    {
        $owner = User::factory()->create();
        $company = TransporterCompany::factory()->for($owner, 'owner')->create(['outstanding_balance' => 50000]);
        $payment = Payment::factory()->pendingConfirmation()->create(['user_id' => $owner->id, 'amount' => 20000]);

        $payload = ['order_id' => $payment->gateway_reference, 'payment_status' => 'COMPLETED'];
        $this->signedPost($payload)->assertOk();
        $this->signedPost($payload)->assertOk();

        $this->assertEquals(30000, $company->fresh()->outstanding_balance);
        $this->assertSame(1, CommissionLedger::where('payment_id', $payment->id)->count());
    }

    public function test_an_invalid_signature_is_rejected(): void
    {
        $body = json_encode(['order_id' => 'whatever', 'payment_status' => 'COMPLETED']);

        $response = $this->call('POST', '/api/webhooks/selcom', [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_X-Selcom-Signature' => 'not-the-right-signature',
        ], $body);

        $response->assertUnauthorized();
    }

    public function test_a_failed_payment_status_marks_the_payment_failed_without_touching_the_balance(): void
    {
        $owner = User::factory()->create();
        $company = TransporterCompany::factory()->for($owner, 'owner')->create(['outstanding_balance' => 50000]);
        $payment = Payment::factory()->pendingConfirmation()->create(['user_id' => $owner->id, 'amount' => 20000]);

        $this->signedPost(['order_id' => $payment->gateway_reference, 'payment_status' => 'FAILED'])->assertOk();

        $this->assertSame('failed', $payment->fresh()->status);
        $this->assertEquals(50000, $company->fresh()->outstanding_balance);
    }

    public function test_a_late_failed_webhook_never_downgrades_an_already_succeeded_payment(): void
    {
        $owner = User::factory()->create();
        TransporterCompany::factory()->for($owner, 'owner')->create(['outstanding_balance' => 50000]);
        $payment = Payment::factory()->succeeded()->create(['user_id' => $owner->id, 'amount' => 20000]);

        $this->signedPost(['order_id' => $payment->gateway_reference, 'payment_status' => 'FAILED'])->assertOk();

        $this->assertSame('succeeded', $payment->fresh()->status);
    }

    public function test_an_unknown_reference_is_acknowledged_without_erroring(): void
    {
        $this->signedPost(['order_id' => 'no-such-reference', 'payment_status' => 'COMPLETED'])->assertOk();
    }
}
