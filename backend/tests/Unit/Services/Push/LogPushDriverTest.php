<?php

namespace Tests\Unit\Services\Push;

use App\Services\Push\Drivers\LogPushDriver;
use Illuminate\Support\Facades\Log;
use Tests\TestCase;

class LogPushDriverTest extends TestCase
{
    public function test_it_logs_the_push_and_reports_success(): void
    {
        Log::shouldReceive('info')
            ->once()
            ->with('Push (log driver)', [
                'tokens' => ['token-1', 'token-2'],
                'title' => 'Bid accepted',
                'body' => 'Your bid was accepted.',
                'data' => ['type' => 'bid_accepted'],
            ]);

        $result = (new LogPushDriver)->send(['token-1', 'token-2'], 'Bid accepted', 'Your bid was accepted.', ['type' => 'bid_accepted']);

        $this->assertTrue($result->successful);
        $this->assertSame([], $result->invalidTokens);
        $this->assertNull($result->error);
    }
}
