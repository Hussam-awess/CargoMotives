<?php

use App\Http\Controllers\DriverLink\DriverLinkPageController;
use App\Http\Controllers\LegalController;
use App\Livewire\Admin;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Public legal pages (Phase 10 launch prep) — the URL both app stores
// require at submission.
Route::get('/legal/privacy', [LegalController::class, 'privacy'])->name('legal.privacy');
Route::get('/legal/terms', [LegalController::class, 'terms'])->name('legal.terms');

/**
 * The Admin tool (PRD §10, TRD §8) — a Laravel Livewire app, session-
 * authenticated against the same `users` table Customers/Companies use
 * via Sanctum, restricted to account_type='admin'. See
 * App\Livewire\Admin\Auth\Login's docblock for the auth mechanism, and
 * bootstrap/app.php's redirectGuestsTo for why guests land on
 * admin.login specifically (rather than the pure-JSON-API default of no
 * redirect at all).
 */
Route::prefix('admin')->name('admin.')->group(function () {
    Route::get('/login', Admin\Auth\Login::class)->name('login');

    Route::post('/logout', function (Request $request) {
        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    })->name('logout');

    Route::middleware(['auth:web', 'account_type:admin'])->group(function () {
        Route::get('/', Admin\Dashboard::class)->name('dashboard');

        Route::get('/companies', Admin\Companies\Index::class)->name('companies.index');
        Route::get('/companies/{company}', Admin\Companies\Show::class)->name('companies.show');

        Route::get('/search', Admin\Search\Index::class)->name('search.index');

        Route::get('/jobs', Admin\Jobs\Index::class)->name('jobs.index');
        Route::get('/jobs/{job}', Admin\Jobs\Show::class)->name('jobs.show');

        Route::get('/disputes', Admin\Disputes\Index::class)->name('disputes.index');
        Route::get('/disputes/{dispute}', Admin\Disputes\Show::class)->name('disputes.show');

        Route::get('/messages', Admin\Messages\Index::class)->name('messages.index');

        Route::get('/activity-log', Admin\ActivityLog\Index::class)->name('activity-log.index');

        Route::get('/gps', Admin\Gps\Index::class)->name('gps.index');

        Route::get('/settings', Admin\Settings\Edit::class)->name('settings.edit');
    });
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
