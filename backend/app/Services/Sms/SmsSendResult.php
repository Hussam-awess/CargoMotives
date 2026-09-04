<?php

namespace App\Services\Sms;

/**
 * Outcome of a single SMS send attempt.
 *
 * Deliberately not a bare bool: OTP and Driver Link delivery both need to
 * degrade gracefully on failure (TRD §5.3), which means the caller has to
 * be able to tell *why* a send failed (bad number vs. provider outage vs.
 * misconfiguration) to decide whether to retry, fall back, or surface an
 * error to the user.
 */
final readonly class SmsSendResult
{
    private function __construct(
        public bool $successful,
        public ?string $providerMessageId,
        public ?string $error,
    ) {}

    public static function success(?string $providerMessageId = null): self
    {
        return new self(successful: true, providerMessageId: $providerMessageId, error: null);
    }

    public static function failure(string $error): self
    {
        return new self(successful: false, providerMessageId: null, error: $error);
    }
}
