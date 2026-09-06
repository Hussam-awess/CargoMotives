<?php

use App\Http\Middleware\EnsureAccountType;
use App\Http\Middleware\EnsureCompanyApproved;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // This is a pure JSON API (no server-rendered login page — the
        // Admin tool, Phase 9, is a separate Blade/Livewire app with its
        // own guard). Laravel's default guest-redirect assumes a 'login'
        // route exists and would otherwise throw a RouteNotFoundException
        // for any unauthenticated request that doesn't explicitly send
        // Accept: application/json (curl without headers, some HTTP
        // clients, etc.) — masking a clean 401 behind a 500.
        $middleware->redirectGuestsTo(fn () => null);

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
