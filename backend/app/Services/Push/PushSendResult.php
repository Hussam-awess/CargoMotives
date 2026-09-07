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

    public static function failure(string $error): self
    {
        return new self(successful: false, invalidTokens: [], error: $error);
    }
}
