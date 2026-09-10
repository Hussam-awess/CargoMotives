<?php

namespace Tests\Unit\Services\Sms;

use App\Services\Sms\Drivers\BeemSmsDriver;
use App\Services\Sms\Drivers\LogSmsDriver;
use App\Services\Sms\SmsManager;
use RuntimeException;
use Tests\TestCase;

class SmsManagerTest extends TestCase
{
    public function test_it_resolves_the_log_driver_by_default(): void
    {
        $manager = $this->app->make(SmsManager::class);

        $this->assertInstanceOf(LogSmsDriver::class, $manager->driver());
    }

    public function test_it_resolves_a_real_beem_driver_once_credentials_are_configured(): void
    {
        config(['sms.default' => 'beem', 'sms.drivers.beem.api_key' => 'key', 'sms.drivers.beem.secret_key' => 'secret']);

        $manager = $this->app->make(SmsManager::class);

        $this->assertInstanceOf(BeemSmsDriver::class, $manager->driver());
    }

    public function test_beem_without_credentials_throws_a_clear_configuration_error(): void
    {
        config(['sms.default' => 'beem', 'sms.drivers.beem.api_key' => null, 'sms.drivers.beem.secret_key' => null]);

        $manager = $this->app->make(SmsManager::class);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('BEEM_API_KEY/BEEM_SECRET_KEY are not set');

        $manager->driver();
    }
}
