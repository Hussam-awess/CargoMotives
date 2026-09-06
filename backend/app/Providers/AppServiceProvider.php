<?php

namespace App\Providers;

use App\Services\Gps\GpsProvider;
use App\Services\Gps\Wialon\WialonGpsProvider;
use App\Services\Sms\SmsGateway;
use App\Services\Sms\SmsManager;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
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

        // Only one GPS provider exists yet (TRD §5: "concrete integrations,
        // not a framework"), so a direct interface binding is enough — a
        // manager/driver-resolution layer (like SmsManager) only earns its
        // keep once a second provider actually exists to switch between.
        $this->app->bind(
            GpsProvider::class,
            fn () => new WialonGpsProvider(config('services.wialon.base_url')),
        );
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Rate limiting on OTP request/verify, per TRD §7 — keyed on
        // phone+IP together so it blunts both "one IP spamming many
        // numbers" and "many IPs hammering one number" without a bare IP
        // limit (which would also throttle legitimate users on shared/NAT'd
        // connections, e.g. a company office).
        RateLimiter::for('otp-request', fn (Request $request) => Limit::perMinute(3)->by($request->input('phone_number').'|'.$request->ip()));

        // A slightly looser cap than otp-request: the OtpService's own
        // max_attempts (config/otp.php) is the primary brute-force guard on
        // a single issued code; this just stops rapid-fire guessing across
        // requests.
        RateLimiter::for('otp-verify', fn (Request $request) => Limit::perMinute(10)->by($request->input('phone_number').'|'.$request->ip()));

        // Blunts brute-forcing an Admin password (TRD §7's "handful of
        // attempts per minute" guidance, same as OTP/login endpoints).
        RateLimiter::for('admin-login', fn (Request $request) => Limit::perMinute(5)->by($request->input('email').'|'.$request->ip()));

        // Defense in depth on top of the token's own unguessability (48
        // random chars) — a driver legitimately reloading/submitting this
        // page a few times a minute is unaffected; a scripted token-guessing
        // attempt is not.
        RateLimiter::for('driver-link', fn (Request $request) => Limit::perMinute(30)->by($request->ip()));
    }
}
