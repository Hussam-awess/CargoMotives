<?php

namespace App\Providers;

use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsManager;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(SmsManager::class);

        // Call sites depend on the SmsGateway interface, never SmsManager or
        // a concrete driver directly — see App\Services\Sms\SmsManager.
        $this->app->bind(SmsGateway::class, fn ($app) => $app->make(SmsManager::class)->driver());
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
