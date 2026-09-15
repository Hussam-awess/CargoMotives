<?php

use App\Http\Controllers\Admin\AdminAuthController;
use App\Http\Controllers\Admin\AdminCompanyController;
use App\Http\Controllers\Admin\AdminTruckController;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\Auth\CustomerAuthController;
use App\Http\Controllers\Auth\ProfileController;
use App\Http\Controllers\Company\CompanyVerificationController;
use App\Http\Controllers\Company\DriverController;
use App\Http\Controllers\Company\FeaturedController as CompanyFeaturedController;
use App\Http\Controllers\Company\GpsConnectionController;
use App\Http\Controllers\Company\TruckController;
use App\Http\Controllers\Customer\FeaturedController as CustomerFeaturedController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\HealthController;
use App\Http\Controllers\Jobs\BidController;
use App\Http\Controllers\Jobs\CompanyJobController;
use App\Http\Controllers\Jobs\JobAssignmentController;
use App\Http\Controllers\Jobs\JobController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\SupportMessageController;
use App\Http\Controllers\Webhooks\SelcomWebhookController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class);

// Private document access — reachable only via a temporary signed URL
// (DocumentStorage::signedUrl), never a guessable path. See TRD §7.
Route::get('/documents/{key}', DocumentController::class)
    ->where('key', '.*')
    ->middleware('signed')
    ->name('documents.show');

// Selcom's payment-outcome callback (TRD §7) — no Sanctum guard (Selcom's
// server has no user session), authenticated instead by its own signature
// check inside the controller. See SelcomWebhookController's docblock.
Route::post('/webhooks/selcom', [SelcomWebhookController::class, 'handle']);

Route::prefix('auth')->group(function () {
    // Transporter Company only (Phase 11) — Customer moved to email+password below.
    Route::post('/otp/request', [AuthController::class, 'requestOtp'])->middleware('throttle:otp-request');
    Route::post('/otp/verify', [AuthController::class, 'verifyOtp'])->middleware('throttle:otp-verify');
    // Password-based login once OTP-signup is done (design-import restyle).
    Route::post('/company/login', [AuthController::class, 'login'])->middleware('throttle:company-login');

    // Customer signup + login (Phase 11): email + password, verified once
    // via an emailed code — see CustomerAuthController's docblock.
    Route::post('/customer/register', [CustomerAuthController::class, 'register'])->middleware('throttle:customer-register');
    Route::post('/customer/register/verify', [CustomerAuthController::class, 'verifyRegistration'])->middleware('throttle:customer-register');
    Route::post('/customer/login', [CustomerAuthController::class, 'login'])->middleware('throttle:customer-login');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/profile/language', [ProfileController::class, 'updateLanguage']);
        Route::post('/profile/name', [ProfileController::class, 'updateName']);
        Route::post('/profile/avatar', [ProfileController::class, 'updateAvatar']);
        Route::post('/profile/business', [ProfileController::class, 'updateBusinessIdentity']);

        // Immediate updates for whichever of phone/email is NOT the
        // caller's login credential (ProfileController::ensureNotCredentialField
        // rejects the other one) — the credential itself still requires the
        // request/confirm-change flow below.
        Route::post('/profile/phone', [ProfileController::class, 'updatePhone']);
        Route::post('/profile/email', [ProfileController::class, 'updateEmail']);

        // Email/phone are login credentials, so changing either goes
        // through a confirmation code sent to the *new* value first
        // (Phase 10.16) — reuses the exact same OTP services registration
        // already depends on.
        Route::post('/profile/email/request-change', [ProfileController::class, 'requestEmailChange'])
            ->middleware('throttle:profile-email-change-request');
        Route::post('/profile/email/confirm-change', [ProfileController::class, 'confirmEmailChange'])
            ->middleware('throttle:profile-email-change-confirm');
        Route::post('/profile/phone/request-change', [ProfileController::class, 'requestPhoneChange'])
            ->middleware('throttle:profile-phone-change-request');
        Route::post('/profile/phone/confirm-change', [ProfileController::class, 'confirmPhoneChange'])
            ->middleware('throttle:profile-phone-change-confirm');
    });
});

// Customer job posting + bid acceptance (AppFlow §3).
Route::middleware(['auth:sanctum', 'account_type:customer'])->group(function () {
    Route::get('/jobs', [JobController::class, 'index']);
    Route::post('/jobs', [JobController::class, 'store']);
    Route::get('/jobs/post-quota', [JobController::class, 'postQuota']);
    Route::get('/jobs/{job}', [JobController::class, 'show']);
    Route::post('/jobs/{job}', [JobController::class, 'update']);
    Route::post('/jobs/{job}/cancel', [JobController::class, 'cancel']);
    Route::post('/jobs/{job}/confirm-delivery', [JobController::class, 'confirmDelivery']);
    Route::post('/jobs/{job}/report-problem', [JobController::class, 'reportProblem']);
    Route::get('/jobs/{job}/bids', [BidController::class, 'index']);

    Route::post('/bids/{bid}/accept', [BidController::class, 'accept']);

    // Featured (Customer) — AppFlow §3.6.
    Route::get('/featured/status', [CustomerFeaturedController::class, 'status']);
    Route::post('/featured/purchase', [CustomerFeaturedController::class, 'purchase']);
});

// A job's message thread (Backend Schema §2.15) — reachable by either
// participant (customer or the assigned company's owner), so this sits
// under plain auth:sanctum rather than either role-specific group above;
// MessageController does its own per-job participant check.
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/jobs/{job}/messages', [MessageController::class, 'index']);
    Route::post('/jobs/{job}/messages', [MessageController::class, 'store']);
});

// A user's standalone Support thread with Admin (Phase 10.15) — distinct
// from the per-job thread above: always the caller's own thread, never
// another user's, so no participant check is needed beyond auth:sanctum.
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/support-messages', [SupportMessageController::class, 'index']);
    Route::post('/support-messages', [SupportMessageController::class, 'store']);
});

// In-app notifications + FCM device tokens (Backend Schema §2.18, AppFlow
// §6) — shared across both roles, same reasoning as messages above.
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::post('/notifications/{notification}/read', [NotificationController::class, 'markRead']);
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::post('/notifications/device-token', [NotificationController::class, 'registerDeviceToken']);
    Route::delete('/notifications/device-token', [NotificationController::class, 'deleteDeviceToken']);
});

Route::prefix('company')->middleware(['auth:sanctum', 'account_type:transporter_company'])->group(function () {
    Route::get('/verification', [CompanyVerificationController::class, 'show']);
    Route::post('/verification', [CompanyVerificationController::class, 'submit']);

    // Fleet management and bidding only open up once the company itself is
    // approved (PRD §6's core flow: verify, then register trucks, then
    // bid) — CompanyHomeGate on the frontend already prevents reaching
    // this UI earlier, this is the backend's own enforcement of the rule.
    Route::middleware('company.approved')->group(function () {
        Route::get('/trucks', [TruckController::class, 'index']);
        Route::post('/trucks', [TruckController::class, 'store']);
        Route::get('/trucks/{truck}', [TruckController::class, 'show']);
        Route::post('/trucks/{truck}', [TruckController::class, 'update']);

        Route::get('/drivers', [DriverController::class, 'index']);
        Route::post('/drivers', [DriverController::class, 'store']);
        Route::post('/drivers/{driver}', [DriverController::class, 'update']);

        // Jobs & Bidding (AppFlow §2.4) — the three Jobs-home tabs.
        Route::get('/jobs/open', [CompanyJobController::class, 'open']);
        Route::get('/jobs/my-bids', [CompanyJobController::class, 'myBids']);
        Route::get('/jobs/active', [CompanyJobController::class, 'active']);
        Route::get('/jobs/{job}', [CompanyJobController::class, 'show']);
        Route::post('/jobs/{job}/bids', [BidController::class, 'store']);
        Route::get('/bid-quota', [BidController::class, 'quota']);
        Route::post('/bids/{bid}/withdraw', [BidController::class, 'withdraw']);

        // Job Assignment & Driver Link (AppFlow §2.5) — picking a truck +
        // driver for a job this company has already won, and re-fetching
        // the resulting link to re-share it.
        Route::post('/jobs/{job}/assign', [JobAssignmentController::class, 'store']);
        Route::get('/jobs/{job}/driver-link', [JobAssignmentController::class, 'driverLink']);

        // Connect GPS (AppFlow §2.3) — Wialon only for now (Phase 6).
        Route::get('/gps-connections', [GpsConnectionController::class, 'index']);
        Route::post('/gps-connections', [GpsConnectionController::class, 'connect']);
        Route::post('/gps-connections/{connection}/import', [GpsConnectionController::class, 'import']);

        // Featured (Company) — AppFlow §2.7.
        Route::get('/featured/status', [CompanyFeaturedController::class, 'status']);
        Route::post('/featured/purchase', [CompanyFeaturedController::class, 'purchase']);
        Route::post('/featured/preferred-routes', [CompanyFeaturedController::class, 'updatePreferredRoutes']);

        // Featured-only fleet map and return-load suggestions.
        Route::get('/fleet/map', [TruckController::class, 'map']);
        Route::get('/jobs/{job}/return-load-suggestions', [CompanyJobController::class, 'returnLoadSuggestions']);
    });
});

Route::prefix('admin')->group(function () {
    Route::post('/login', [AdminAuthController::class, 'login'])->middleware('throttle:admin-login');

    Route::middleware(['auth:sanctum', 'account_type:admin'])->group(function () {
        Route::get('/companies', [AdminCompanyController::class, 'index']);
        Route::get('/companies/{company}', [AdminCompanyController::class, 'show']);
        Route::post('/companies/{company}/approve', [AdminCompanyController::class, 'approve']);
        Route::post('/companies/{company}/reject', [AdminCompanyController::class, 'reject']);

        Route::get('/trucks', [AdminTruckController::class, 'index']);
        Route::get('/trucks/{truck}', [AdminTruckController::class, 'show']);
        Route::post('/trucks/{truck}/approve', [AdminTruckController::class, 'approve']);
        Route::post('/trucks/{truck}/reject', [AdminTruckController::class, 'reject']);
    });
});
