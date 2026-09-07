<?php

namespace App\Http\Controllers;

use App\Http\Requests\RegisterDeviceTokenRequest;
use App\Http\Resources\NotificationResource;
use App\Models\DeviceToken;
use App\Models\Notification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * In-app notifications (Backend Schema §2.18, AppFlow §3.1/§2.1's "bell
 * icon on the home screen... rather than a dedicated tab") and FCM device
 * token registration. Deliberately plain REST + refresh-on-open (TRD §4:
 * notification lists are explicitly not one of the two WebSocket use
 * cases) — the bell badge is a pull, not a push-driven live count.
 *
 * Shared across both roles under plain auth:sanctum, same reasoning as
 * MessageController: the same table serves Customers and Companies, and a
 * device-token registration doesn't care which role is logged in either.
 */
class NotificationController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $notifications = Notification::where('user_id', $request->user()->id)
            ->latest('created_at')
            ->paginate(20);

        return NotificationResource::collection($notifications);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $count = Notification::where('user_id', $request->user()->id)->whereNull('read_at')->count();

        return response()->json(['unread_count' => $count]);
    }

    public function markRead(Request $request, Notification $notification): NotificationResource
    {
        abort_unless($notification->user_id === $request->user()->id, 404);

        if ($notification->read_at === null) {
            $notification->update(['read_at' => now()]);
        }

        return new NotificationResource($notification);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['message' => 'All notifications marked as read.']);
    }

    /**
     * Registers (or refreshes) the current device's FCM token. Upserts by
     * token, not by user — the same physical device token re-registering
     * under a different account (a shared device, or a logout/login
     * switch) should move to the new owner, not create a duplicate row a
     * previous account's session would still receive pushes on.
     */
    public function registerDeviceToken(RegisterDeviceTokenRequest $request): JsonResponse
    {
        DeviceToken::updateOrCreate(
            ['token' => $request->string('token')->toString()],
            ['user_id' => $request->user()->id, 'platform' => $request->string('platform')->toString()],
        );

        return response()->json(['message' => 'Device token registered.'], 201);
    }

    /**
     * Called on logout so a signed-out device stops receiving pushes meant
     * for the account that just left it — mirrors why Sanctum revokes the
     * token itself on logout, just for the push channel instead of the API.
     */
    public function deleteDeviceToken(Request $request): JsonResponse
    {
        $request->validate(['token' => ['required', 'string']]);

        DeviceToken::where('user_id', $request->user()->id)
            ->where('token', $request->string('token'))
            ->delete();

        return response()->json(['message' => 'Device token removed.']);
    }
}
