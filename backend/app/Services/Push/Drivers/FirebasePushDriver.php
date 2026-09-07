<?php

namespace App\Services\Push\Drivers;

use App\Services\Push\PushGateway;
use App\Services\Push\PushSendResult;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification as FirebaseNotification;
use Throwable;

/**
 * The real driver — PUSH_DRIVER=firebase. Uses kreait/firebase-php rather
 * than a hand-rolled HTTP client: unlike Selcom/Wialon's simpler API-key or
 * HMAC schemes, FCM's real HTTP v1 API requires a Google OAuth2 token
 * exchanged from a service-account JWT, which is exactly the kind of
 * token-signing/caching machinery a client library exists to get right —
 * reaching for the standard one here isn't building a speculative
 * framework, it's the concrete integration for this specific provider.
 *
 * Never throws: every failure mode (missing/invalid credentials file,
 * network failure, a malformed token) is caught and returned as a
 * PushSendResult::failure(), matching SmsGateway's contract and TRD §5.3's
 * graceful-degradation principle — a push failure must never affect the
 * in-app notification, which is already written before this driver runs.
 */
class FirebasePushDriver implements PushGateway
{
    public function send(array $tokens, string $title, string $body, array $data = []): PushSendResult
    {
        if ($tokens === []) {
            return PushSendResult::success();
        }

        $credentialsPath = config('fcm.credentials_path');

        if (blank($credentialsPath) || ! is_file($credentialsPath)) {
            return PushSendResult::failure(
                'FCM_CREDENTIALS_PATH is not set or does not point to a real file — see README for how to obtain one.'
            );
        }

        try {
            $messaging = (new Factory)->withServiceAccount($credentialsPath)->createMessaging();

            $message = CloudMessage::new()
                ->withNotification(FirebaseNotification::create($title, $body))
                ->withData($data);

            $report = $messaging->sendMulticast($message, $tokens);

            $invalidTokens = [...$report->invalidTokens(), ...$report->unknownTokens()];

            if ($report->successes()->count() === 0) {
                return PushSendResult::failure('Every device token in this send failed.', $invalidTokens);
            }

            return PushSendResult::success($invalidTokens);
        } catch (Throwable $e) {
            Log::warning('FCM push send failed', ['error' => $e->getMessage()]);

            return PushSendResult::failure($e->getMessage());
        }
    }
}
