<?php

namespace App\Services\Push\Drivers;

use App\Services\Push\PushGateway;
use App\Services\Push\PushSendResult;
use Illuminate\Support\Facades\Log;

/**
 * Local-dev / CI stand-in: writes the push to the log instead of sending
 * it, the exact PUSH_DRIVER=log counterpart to LogSmsDriver. Lets the
 * whole notification pipeline (creation, in-app list, read state) be built
 * and exercised end-to-end without a real Firebase project — only actual
 * device delivery needs one.
 *
 * To see what would have been pushed while testing locally: tail
 * storage/logs/laravel.log for "Push (log driver)".
 */
class LogPushDriver implements PushGateway
{
    public function send(array $tokens, string $title, string $body, array $data = []): PushSendResult
    {
        Log::info('Push (log driver)', [
            'tokens' => $tokens,
            'title' => $title,
            'body' => $body,
            'data' => $data,
        ]);

        return PushSendResult::success();
    }
}
