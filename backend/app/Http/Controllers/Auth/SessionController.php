<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Settings > Active sessions: every device signed in to this account (one
 * Sanctum token each, labelled with the device name sent at login), and a
 * way to sign any other one out — e.g. a lost phone, or a device the user
 * doesn't recognize.
 */
class SessionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $currentId = $this->currentTokenId($request);

        $sessions = $request->user()->tokens()
            ->orderByDesc('last_used_at')
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (PersonalAccessToken $token) => [
                'id' => $token->id,
                'device_name' => $token->name,
                'last_used_at' => $token->last_used_at?->toIso8601String(),
                'created_at' => $token->created_at?->toIso8601String(),
                'is_current' => $token->id === $currentId,
            ]);

        return response()->json(['data' => $sessions]);
    }

    public function destroy(Request $request, int $session): JsonResponse
    {
        abort_if($session === $this->currentTokenId($request), 422, 'Use Log out to end the session on this device.');

        $deleted = $request->user()->tokens()->where('id', $session)->delete();

        abort_if($deleted === 0, 404, 'That session was not found.');

        return response()->json(['message' => 'Signed out of that device.']);
    }

    public function destroyOthers(Request $request): JsonResponse
    {
        $currentId = $this->currentTokenId($request);

        $count = $request->user()->tokens()
            ->when($currentId, fn ($query) => $query->where('id', '!=', $currentId))
            ->delete();

        return response()->json(['message' => 'Signed out of all other devices.', 'signed_out' => $count]);
    }

    /**
     * Null under actingAs() in tests (a TransientToken has no id) — same
     * guard ProfileController::changePassword() uses.
     */
    private function currentTokenId(Request $request): ?int
    {
        $token = $request->user()->currentAccessToken();

        return $token instanceof PersonalAccessToken ? $token->id : null;
    }
}
