<?php

use App\Http\Controllers\DriverLink\DriverLinkPageController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// The Driver Link (AppFlow §4, TRD's "lightweight server-rendered mobile
// web page — no login, no app install"). Plain web routes (session-based
// CSRF only) — the token itself, not a guard, is the authorization; see
// App\Models\DriverLink and DriverLinkPageController's docblock.
Route::prefix('driver-link')->middleware('throttle:driver-link')->group(function () {
    Route::get('/{token}', [DriverLinkPageController::class, 'show'])->name('driver-link.show');
    Route::post('/{token}/status', [DriverLinkPageController::class, 'updateStatus'])->name('driver-link.status');
    Route::post('/{token}/proof-of-delivery', [DriverLinkPageController::class, 'submitProofOfDelivery'])->name('driver-link.pod');
});
