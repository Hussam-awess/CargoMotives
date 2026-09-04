<?php

namespace Tests\Unit\Services\Sms;

use App\Services\Sms\Drivers\LogSmsDriver;
use Illuminate\Support\Facades\Log;
use Tests\TestCase;

class LogSmsDriverTest extends TestCase
{
    public function test_it_logs_the_message_and_reports_success(): void
    {
        Log::shouldReceive('info')
            ->once()
            ->with('SMS (log driver)', ['to' => '+255700000000', 'body' => 'Your code is 123456']);

        $result = (new LogSmsDriver)->send('+255700000000', 'Your code is 123456');

        $this->assertTrue($result->successful);
        $this->assertNotNull($result->providerMessageId);
        $this->assertNull($result->error);
    }
}
