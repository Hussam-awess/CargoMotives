<?php

namespace Tests\Unit\Services\Sms\Drivers;

use App\Services\Sms\Drivers\BeemSmsDriver;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Exercises BeemSmsDriver against faked HTTP responses shaped exactly like
 * the real Beem API — confirmed correct by live-sending real SMS to three
 * real numbers on 2026-09-18 (see BeemSmsDriver's own docblock).
 */
class BeemSmsDriverTest extends TestCase
{
    private function driver(): BeemSmsDriver
    {
        return new BeemSmsDriver('test-api-key', 'test-secret-key', 'CargoMotiv');
    }

    public function test_a_successful_send_reports_success_with_the_provider_message_id(): void
    {
        Http::fake(['*' => Http::response(['successful' => true, 'request_id' => 987654, 'code' => 100])]);

        $result = $this->driver()->send('+255712345678', 'Your code is 123456');

        $this->assertTrue($result->successful);
        $this->assertSame('987654', $result->providerMessageId);
        $this->assertNull($result->error);
    }

    public function test_the_request_strips_the_leading_plus_and_sends_basic_auth(): void
    {
        Http::fake(['*' => Http::response(['successful' => true, 'request_id' => 1])]);

        $this->driver()->send('+255712345678', 'Your code is 123456');

        Http::assertSent(function ($request) {
            $authHeader = $request->header('Authorization')[0] ?? '';
            $expected = 'Basic '.base64_encode('test-api-key:test-secret-key');

            return $request->url() === 'https://apisms.beem.africa/v1/send'
                && $authHeader === $expected
                && $request['source_addr'] === 'CargoMotiv'
                && $request['message'] === 'Your code is 123456'
                && $request['recipients'][0]['dest_addr'] === '255712345678';
        });
    }

    public function test_unicode_is_transliterated_so_beem_does_not_reject_the_message(): void
    {
        Http::fake(['*' => Http::response(['successful' => true, 'request_id' => 1])]);

        $this->driver()->send('+255712345678', "New job: Kariakoo \u{2192} Mbezi \u{2014} “fragile” café 🚚");

        Http::assertSent(fn ($request) => $request['message'] === 'New job: Kariakoo -> Mbezi - "fragile" cafe ');
    }

    public function test_plain_text_passes_through_unchanged(): void
    {
        $this->assertSame("Line one\nLine two: 1,000 TZS (ok)", BeemSmsDriver::toPlainText("Line one\nLine two: 1,000 TZS (ok)"));
    }

    public function test_a_declined_message_is_reported_as_a_failure(): void
    {
        Http::fake(['*' => Http::response(['successful' => false, 'message' => 'Insufficient credit.'])]);

        $result = $this->driver()->send('+255712345678', 'Your code is 123456');

        $this->assertFalse($result->successful);
        $this->assertSame('Insufficient credit.', $result->error);
    }

    public function test_an_unreachable_gateway_is_reported_as_a_failure_not_thrown(): void
    {
        Http::fake(fn () => throw new ConnectionException('Connection timed out'));

        $result = $this->driver()->send('+255712345678', 'Your code is 123456');

        $this->assertFalse($result->successful);
        $this->assertStringContainsString('Could not reach Beem', $result->error);
    }

    public function test_a_non_json_or_error_response_is_reported_as_a_failure(): void
    {
        Http::fake(['*' => Http::response('Internal Server Error', 500)]);

        $result = $this->driver()->send('+255712345678', 'Your code is 123456');

        $this->assertFalse($result->successful);
        $this->assertStringContainsString('HTTP 500', $result->error);
    }
}
