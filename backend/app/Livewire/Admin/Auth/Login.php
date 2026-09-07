<?php

namespace App\Livewire\Admin\Auth;

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * Admin's own login (TRD §7/§8) — email+password against the same `users`
 * table Customers/Companies use, restricted to account_type='admin'.
 * User::getAuthPassword() already points at password_hash, so Auth::attempt
 * works against it unmodified (see App\Models\User).
 *
 * Rate limiting mirrors the 'admin-login' named limiter already registered
 * in AppServiceProvider for the old Sanctum-based /api/admin/login — but a
 * route-level `throttle:` middleware can't gate this, because a Livewire
 * component's actions are dispatched through Livewire's own single AJAX
 * endpoint, not the page's own route. The same limit (5/minute per
 * email+ip) is enforced directly here instead.
 */
#[Layout('layouts.admin')]
class Login extends Component
{
    public string $email = '';

    public string $password = '';

    public bool $remember = false;

    public function login(): void
    {
        $this->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $throttleKey = Str::lower($this->email).'|'.request()->ip();

        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $this->addError('email', 'Too many attempts. Try again in '.RateLimiter::availableIn($throttleKey).' seconds.');

            return;
        }

        $credentials = ['email' => $this->email, 'password' => $this->password, 'account_type' => 'admin'];

        if (! Auth::guard('web')->attempt($credentials, $this->remember)) {
            RateLimiter::hit($throttleKey, 60);
            // Same message regardless of which part was wrong — don't
            // reveal whether the email belongs to an admin account.
            $this->addError('email', 'Invalid credentials.');

            return;
        }

        RateLimiter::clear($throttleKey);
        // The session() helper (not request()->session()) — a Livewire
        // component's action runs without a real HTTP-kernel request
        // ever passing through StartSession middleware, so
        // request()->session() has nothing attached yet; the session
        // manager itself is still available directly.
        session()->regenerate();

        $this->redirect(route('admin.dashboard'), navigate: true);
    }

    public function render()
    {
        return view('livewire.admin.auth.login');
    }
}
