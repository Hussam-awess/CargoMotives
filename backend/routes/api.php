<?php

use App\Http\Controllers\Admin\AdminAuthController;
use App\Http\Controllers\Admin\AdminCompanyController;
use App\Http\Controllers\Admin\AdminTruckController;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\Auth\ProfileController;
use App\Http\Controllers\Company\CommissionController;
use App\Http\Controllers\Company\CompanyVerificationController;
use App\Http\Controllers\Company\DriverController;
use App\Http\Controllers\Company\GpsConnectionController;
use App\Http\Controllers\Company\TruckController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\HealthController;
use App\Http\Controllers\Jobs\BidController;
use App\Http\Controllers\Jobs\CompanyJobController;
use App\Http\Controllers\Jobs\JobAssignmentController;
use App\Http\Controllers\Jobs\JobController;
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
    Route::post('/otp/request', [AuthController::class, 'requestOtp'])->middleware('throttle:otp-request');
    Route::post('/otp/verify', [AuthController::class, 'verifyOtp'])->middleware('throttle:otp-verify');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/profile', [ProfileController::class, 'complete']);
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
    Route::get('/jobs/{job}/bids', [BidController::class, 'index']);

    Route::post('/bids/{bid}/accept', [BidController::class, 'accept']);
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

        // Commission balance, history, and paying it down (AppFlow §2.6/§2.7).
        Route::get('/commission/summary', [CommissionController::class, 'summary']);
        Route::get('/commission/ledger', [CommissionController::class, 'ledger']);
        Route::post('/commission/payments', [CommissionController::class, 'initiatePayment']);
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
