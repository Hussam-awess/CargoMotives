<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ResendTwoFactorCodeRequest;
use App\Http\Requests\Auth\UpdateTwoFactorRequest;
use App\Http\Requests\Auth\VerifyTwoFactorLoginRequest;
use App\Http\Resources\UserResource;
use App\Services\Auth\OtpCooldownException;
use App\Services\Auth\TwoFactorChallenge;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Two-factor login (second step after a correct password — see
 * TwoFactorChallenge) and the Settings toggle that turns it on or off.
 * Shared by Customer and Transporter Company; the channel (email vs SMS)
 * is decided per account inside TwoFactorChallenge.
 */
class TwoFactorController extends Controller
{
    public function __construct(private readonly TwoFactorChallenge $challenge) {}

    public function verifyLogin(VerifyTwoFactorLoginRequest $request): JsonResponse
    {
        $result = $this->challenge->complete(
            $request->string('challenge_token')->toString(),
            $request->string('code')->toString(),
        );

        return response()->json([
            'token' => $result['user']->createToken($result['device_name'])->plainTextToken,
            'user' => new UserResource($result['user']),
        ]);
    }

    public function resendLoginCode(ResendTwoFactorCodeRequest $request): JsonResponse
    {
        try {
            $this->challenge->resend($request->string('challenge_token')->toString());
        } catch (OtpCooldownException $e) {
            return response()->json([
                'message' => $e->getMessage(),
                'seconds_remaining' => $e->secondsRemaining,
            ], 429);
        }

        return response()->json(['message' => 'A new code has been sent.']);
    }

    public function update(UpdateTwoFactorRequest $request): UserResource
    {
        $user = $request->user();

        if (! Hash::check($request->string('current_password')->toString(), $user->password_hash ?? '')) {
            throw ValidationException::withMessages(['current_password' => ['That password is incorrect.']]);
        }

        $user->forceFill(['two_factor_enabled' => $request->boolean('enabled')])->save();

        return new UserResource($user);
    }
}
