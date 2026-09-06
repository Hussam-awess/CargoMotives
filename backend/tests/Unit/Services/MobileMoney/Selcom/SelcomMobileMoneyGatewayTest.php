<?php

namespace Tests\Unit\Services\MobileMoney\Selcom;

use App\Services\MobileMoney\MobileMoneyGatewayException;
use App\Services\MobileMoney\Selcom\SelcomMobileMoneyGateway;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Exercises SelcomMobileMoneyGateway against faked HTTP responses — see
 * this class's own docblock for why the exact wire shape is a best-effort
 * model rather than verified against a live Selcom account (no
 * SELCOM_* credentials exist in this environment). What IS fully
 * verified here: request/response handling, error propagation, and the
 * webhook signature check this app's own security depends on.
 */
class SelcomMobileMoneyGatewayTest extends TestCase
{
    private function gateway(): SelcomMobileMoneyGateway
    {
        return new SelcomMobileMoneyGateway(
            'https://apigwtest.selcommobile.com',
            'test-api-key',
            'test-api-secret',
            'test-vendor',
            'test-webhook-secret',
        );
    }

    public function test_a_successful_charge_returns_the_provider_reference(): void
    {
        Http::fake(['*' => Http::response(['result' => 'SUCCESS', 'reference' => 'SEL-REF-123'])]);

        $result = $this->gateway()->initiateCharge('order-1', 50000, 'mpesa', '0712345678');

        $this->assertTrue($result->initiated);
        $this->assertSame('SEL-REF-123', $result->providerReference);
    }

    public function test_a_signed_authorization_header_is_sent(): void
    {
        Http::fake(['*' => Http::response(['result' => 'SUCCESS', 'reference' => 'ref'])]);

        $this->gateway()->initiateCharge('order-1', 50000, 'mpesa', '0712345678');

        Http::assertSent(function ($request) {
            return str_starts_with($request->header('Authorization')[0] ?? '', 'SELCOM ')
                && $request->hasHeader('Digest-Method')
                && $request->hasHeader('Timestamp');
        });
    }

    public function test_a_declined_result_is_reported_as_not_initiated(): void
    {
        Http::fake(['*' => Http::response(['result' => 'FAIL', 'message' => 'Insufficient funds.'])]);

        $result = $this->gateway()->initiateCharge('order-1', 50000, 'mpesa', '0712345678');

        $this->assertFalse($result->initiated);
        $this->assertSame('Insufficient funds.', $result->error);
    }

    public function test_an_unreachable_gateway_throws(): void
    {
        Http::fake(fn () => throw new ConnectionException('Connection timed out'));

        $this->expectException(MobileMoneyGatewayException::class);

        $this->gateway()->initiateCharge('order-1', 50000, 'mpesa', '0712345678');
    }

    public function test_a_correctly_signed_webhook_verifies(): void
    {
        $body = '{"order_id":"order-1","payment_status":"COMPLETED"}';
        $signature = hash_hmac('sha256', $body, 'test-webhook-secret');

        $this->assertTrue($this->gateway()->verifyWebhookSignature($body, $signature));
    }

    public function test_a_tampered_body_fails_verification(): void
    {
        $signature = hash_hmac('sha256', '{"order_id":"order-1","payment_status":"COMPLETED"}', 'test-webhook-secret');

        $tamperedBody = '{"order_id":"order-1","payment_status":"FAILED"}';

        $this->assertFalse($this->gateway()->verifyWebhookSignature($tamperedBody, $signature));
    }

    public function test_a_missing_signature_fails_verification(): void
    {
        $this->assertFalse($this->gateway()->verifyWebhookSignature('{}', null));
    }
}
