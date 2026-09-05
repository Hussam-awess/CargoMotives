<?php

namespace App\Services\Auth;

/**
 * Outcome of one OTP verify attempt. A plain bool would force the caller to
 * guess why it failed; distinguishing the reason lets the controller return
 * an honest, specific message (matching the brief's "don't silently hide
 * errors" rule) without leaking anything sensitive — "wrong code" vs.
 * "expired" vs. "too many attempts" are all safe to say to the caller,
 * unlike e.g. whether a phone number is registered.
 */
final readonly class OtpVerificationResult
{
    private function __construct(
        public bool $successful,
        public ?string $reason,
    ) {}

    public static function success(): self
    {
        return new self(successful: true, reason: null);
    }

    public static function failure(string $reason): self
    {
        return new self(successful: false, reason: $reason);
    }
}
