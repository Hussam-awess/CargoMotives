<?php

namespace App\Services\Auth;

use Exception;

/**
 * Thrown when an OTP is requested again too soon for the same phone number.
 * Caught by the controller and turned into a 429 with $secondsRemaining, so
 * the app can show "resend in 42s" instead of a generic error.
 */
class OtpCooldownException extends Exception
{
    public function __construct(public readonly int $secondsRemaining)
    {
        parent::__construct("An OTP was already sent to this number; try again in {$secondsRemaining}s.");
    }
}
