<?php

namespace App\Providers;

use App\Models\Bid;
use App\Models\Dispute;
use App\Models\Job;
use App\Models\Message;
use App\Models\Payment;
use App\Models\SupportMessage;
use App\Models\TransporterCompany;
use App\Models\Truck;
use App\Observers\BidObserver;
use App\Observers\DisputeObserver;
use App\Observers\JobObserver;
use App\Observers\MessageObserver;
use App\Observers\PaymentObserver;
use App\Observers\SupportMessageObserver;
use App\Observers\TransporterCompanyObserver;
use App\Observers\TruckObserver;
use App\Services\Gps\GpsProviderManager;
use App\Services\Gps\Traccar\TraccarGpsProvider;
use App\Services\Gps\Tracksolid\TracksolidGpsProvider;
use App\Services\Gps\Wialon\WialonGpsProvider;
use App\Services\MobileMoney\MobileMoneyGateway;
use App\Services\MobileMoney\Selcom\SelcomMobileMoneyGateway;
use App\Services\Push\PushGateway;
use App\Services\Push\PushManager;
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

        $this->app->singleton(PushManager::class);

        // Same manager/driver pattern as SmsGateway above — call sites
        // depend on the PushGateway interface, never PushManager or a
        // concrete driver directly.
        $this->app->bind(PushGateway::class, fn ($app) => $app->make(PushManager::class)->driver());

        // Each concrete provider bound individually (resolvable/fakeable on
        // its own in tests) — GpsProviderManager::driver() picks the right
        // one per GpsConnection.provider, since a company's own choice of
        // Wialon/Traccar/Tracksolid is per-connection, not app-wide like
        // SmsGateway/PushGateway's single active driver.
        $this->app->bind(WialonGpsProvider::class, fn () => new WialonGpsProvider(config('services.wialon.base_url')));
        $this->app->bind(TraccarGpsProvider::class, fn () => new TraccarGpsProvider(config('services.traccar.base_url')));
        $this->app->bind(TracksolidGpsProvider::class, fn () => new TracksolidGpsProvider(config('services.tracksolid_pro.base_url')));
        $this->app->singleton(GpsProviderManager::class);

        // Same reasoning as GpsProvider above — one aggregator (TRD §1),
        // so a direct binding, no manager layer.
        $this->app->bind(MobileMoneyGateway::class, fn () => new SelcomMobileMoneyGateway(
            config('services.selcom.base_url'),
            config('services.selcom.api_key'),
            config('services.selcom.api_secret'),
            config('services.selcom.vendor_id'),
            config('services.selcom.webhook_secret'),
        ));
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

        // Same reasoning as otp-request/otp-verify, keyed by email instead
        // of phone — covers both /customer/register (issues the code) and
        // /customer/register/verify (guesses it).
        RateLimiter::for('customer-register', fn (Request $request) => Limit::perMinute(5)->by($request->input('email').'|'.$request->ip()));

        // Same reasoning as admin-login.
        RateLimiter::for('customer-login', fn (Request $request) => Limit::perMinute(5)->by($request->input('email').'|'.$request->ip()));

        // Same reasoning as customer-login, keyed by phone instead of email
        // (design-import restyle — Transporter Company gained a password).
        RateLimiter::for('company-login', fn (Request $request) => Limit::perMinute(5)->by($request->input('phone_number').'|'.$request->ip()));

        // Defense in depth on top of the token's own unguessability (48
        // random chars) — a driver legitimately reloading/submitting this
        // page a few times a minute is unaffected; a scripted token-guessing
        // attempt is not.
        RateLimiter::for('driver-link', fn (Request $request) => Limit::perMinute(30)->by($request->ip()));

        // Profile email/phone change (Phase 10.16) — authenticated, so keyed
        // by the user's own id rather than a request field; same
        // request/verify split and per-minute shape as otp-request/otp-verify.
        RateLimiter::for('profile-email-change-request', fn (Request $request) => Limit::perMinute(3)->by($request->user()->id));
        RateLimiter::for('profile-email-change-confirm', fn (Request $request) => Limit::perMinute(10)->by($request->user()->id));
        RateLimiter::for('profile-phone-change-request', fn (Request $request) => Limit::perMinute(3)->by($request->user()->id));
        RateLimiter::for('profile-phone-change-confirm', fn (Request $request) => Limit::perMinute(10)->by($request->user()->id));

        // Phase 9's activity_logs (Backend Schema §2.16) is populated
        // entirely through observers rather than threading a logging call
        // into every controller across Phases 1-8 — see
        // App\Services\ActivityLog\ActivityLogger's docblock for why.
        Job::observe(JobObserver::class);
        TransporterCompany::observe(TransporterCompanyObserver::class);
        Truck::observe(TruckObserver::class);
        Bid::observe(BidObserver::class);
        Payment::observe(PaymentObserver::class);
        Dispute::observe(DisputeObserver::class);

        // MessageObserver fires notifications only (Phase 8 deliberately
        // never audit-logs messages — see MessageObserver's docblock) —
        // it's registered separately from the activity-log comment above
        // since it doesn't share that motivation.
        Message::observe(MessageObserver::class);
        SupportMessage::observe(SupportMessageObserver::class);
    }
}
