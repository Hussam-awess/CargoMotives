<?php

use App\Http\Controllers\Admin\AdminAuthController;
use App\Http\Controllers\Admin\AdminCompanyController;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\Auth\ProfileController;
use App\Http\Controllers\Company\CompanyVerificationController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\HealthController;
use Illuminate\Support\Facades\Route;

Route::get('/health', HealthController::class);

// Private document access — reachable only via a temporary signed URL
// (DocumentStorage::signedUrl), never a guessable path. See TRD §7.
Route::get('/documents/{key}', DocumentController::class)
    ->where('key', '.*')
    ->middleware('signed')
    ->name('documents.show');

Route::prefix('auth')->group(function () {
    Route::post('/otp/request', [AuthController::class, 'requestOtp'])->middleware('throttle:otp-request');
    Route::post('/otp/verify', [AuthController::class, 'verifyOtp'])->middleware('throttle:otp-verify');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/profile', [ProfileController::class, 'complete']);
    });
});

Route::prefix('company')->middleware(['auth:sanctum', 'account_type:transporter_company'])->group(function () {
    Route::get('/verification', [CompanyVerificationController::class, 'show']);
    Route::post('/verification', [CompanyVerificationController::class, 'submit']);
});

Route::prefix('admin')->group(function () {
    Route::post('/login', [AdminAuthController::class, 'login'])->middleware('throttle:admin-login');

    Route::middleware(['auth:sanctum', 'account_type:admin'])->group(function () {
        Route::get('/companies', [AdminCompanyController::class, 'index']);
        Route::get('/companies/{company}', [AdminCompanyController::class, 'show']);
        Route::post('/companies/{company}/approve', [AdminCompanyController::class, 'approve']);
        Route::post('/companies/{company}/reject', [AdminCompanyController::class, 'reject']);
    });
});
