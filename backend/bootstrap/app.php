<?php

use App\Console\Commands\CheckGpsSignalLoss;
use App\Http\Middleware\EnsureAccountType;
use App\Http\Middleware\EnsureCompanyApproved;
use App\Jobs\PollGpsPositionsJob;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    // withRouting(channels: ...) would register /broadcasting/auth under
    // the default 'web' session-guard middleware — wrong for this app,
    // which is Sanctum-token authenticated throughout, not session-based.
    // Registered explicitly instead, under /api and auth:sanctum, so a
    // private channel subscription (job.{id}, TRD §4) authenticates the
    // same way every other endpoint does.
    ->withBroadcasting(
        __DIR__.'/../routes/channels.php',
        ['middleware' => ['api', 'auth:sanctum'], 'prefix' => 'api'],
    )
    ->withSchedule(function (Schedule $schedule): void {
        // The async GPS pipeline's poll stage (TRD §5.2) — Wialon has no
        // outbound webhook in this integration, so a scheduled poll is how
        // positions get in at all. Laravel's scheduler runs no more often
        // than per-minute; the TRD's "every 30-60 seconds" target is
        // satisfied well enough at MVP scale by polling every minute —
        // tightening this later is a one-line change, not a redesign.
        $schedule->job(new PollGpsPositionsJob)->everyMinute()->withoutOverlapping();

        // The other half of graceful degradation (TRD §5.3): catches a
        // connected truck's feed going quiet mid-job. Runs independently
        // of the poll above so a slow/failing poll cycle never delays
        // detecting signal loss.
        $schedule->command(CheckGpsSignalLoss::class)->everyMinute();
    })
    ->withMiddleware(function (Middleware $middleware): void {
        // Everywhere else, this is a pure JSON API (no server-rendered
        // login page) — Laravel's default guest-redirect assumes a
        // 'login' route exists and would otherwise throw a
        // RouteNotFoundException for any unauthenticated request that
        // doesn't explicitly send Accept: application/json (curl without
        // headers, some HTTP clients, etc.), masking a clean 401 behind a
        // 500. The one exception is the Admin tool (Phase 9, TRD §8) — a
        // real server-rendered Blade/Livewire app under /admin, session-
        // authenticated via the 'web' guard — where a guest should land
        // on its actual login page instead.
        $middleware->redirectGuestsTo(
            fn (Request $request) => $request->is('admin', 'admin/*') ? route('admin.login') : null,
        );

        $middleware->alias([
            'account_type' => EnsureAccountType::class,
            'company.approved' => EnsureCompanyApproved::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
