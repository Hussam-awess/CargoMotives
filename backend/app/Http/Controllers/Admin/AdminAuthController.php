<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Concerns\HandlesLoginLockout;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\Auth\LoginThrottle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Admin's own login — email+password, not the Customer/Company phone+OTP
 * flow (TRD §7 lists Sanctum tokens for "Customers, Companies, and Admin",
 * implying separate login mechanisms; `users.password_hash` has sat unused
 * since Phase 1 for exactly this). This is intentionally minimal: just
 * enough to protect Phase 2's verification-review endpoints ahead of the
 * full Admin tool (Phase 9), per the Implementation Plan's "a protected
 * endpoint is fine before the full Admin tool."
 */
class AdminAuthController extends Controller
{
    use HandlesLoginLockout;

    public function __construct(private readonly LoginThrottle $loginThrottle) {}

    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $email = $request->string('email')->toString();
        $throttleKey = "admin:{$email}";

        if ($this->loginThrottle->locked($throttleKey)) {
            return $this->lockoutResponse($throttleKey);
        }

        $user = User::where('account_type', 'admin')->where('email', $email)->first();

        if (! $user || ! Hash::check($request->string('password'), $user->password_hash ?? '')) {
            $this->loginThrottle->recordFailure($throttleKey);

            // Same message either way — don't reveal whether the email
            // belongs to an account.
            throw ValidationException::withMessages(['email' => ['Invalid credentials.']]);
        }

        $this->loginThrottle->clear($throttleKey);

        return response()->json([
            'token' => $user->createToken('admin-web')->plainTextToken,
            'user' => new UserResource($user),
        ]);
    }
}
