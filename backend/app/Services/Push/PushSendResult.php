<?php

namespace App\Services\Push;

/**
 * Outcome of one push send attempt against potentially several device
 * tokens for the same user. Deliberately not a bare bool — same reasoning
 * as SmsSendResult (TRD §5.3 graceful degradation): the caller needs to
 * know which specific tokens are dead (unregistered/invalid — safe to
 * delete from device_tokens) versus whether the send failed outright
 * (misconfiguration, provider outage — the tokens themselves are still
 * good, don't touch them).
 */
final readonly class PushSendResult
{
    /**
     * @param  string[]  $invalidTokens  Tokens FCM reported as unregistered/invalid — safe to delete.
     */
    private function __construct(
        public bool $successful,
        public array $invalidTokens,
        public ?string $error,
    ) {}

    /**
     * @param  string[]  $invalidTokens
     */
    public static function success(array $invalidTokens = []): self
    {
        return new self(successful: true, invalidTokens: $invalidTokens, error: null);
    }

    /**
     * @param  string[]  $invalidTokens  Still reportable on a failure: "no
     *                                   token got a real delivery" and "this specific token is dead and
     *                                   should be pruned" are independent facts — a single-device send
     *                                   where that one token happens to be invalid is a real case (not
     *                                   just a multi-device partial-failure one), and its dead token
     *                                   needs to be reported here or SendPushNotificationJob can never
     *                                   prune it.
     */
    public static function failure(string $error, array $invalidTokens = []): self
    {
        return new self(successful: false, invalidTokens: $invalidTokens, error: $error);
    }
}
