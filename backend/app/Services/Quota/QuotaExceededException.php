<?php

namespace App\Services\Quota;

use Exception;

/**
 * Thrown when a caller has hit its rolling-window limit. $secondsUntilSlotFrees
 * is when the OLDEST counted action will age out of the window, freeing up
 * one slot — not when the whole quota resets (a rolling window has no single
 * reset moment).
 */
class QuotaExceededException extends Exception
{
    public function __construct(public readonly int $secondsUntilSlotFrees)
    {
        parent::__construct("Quota exceeded; the next slot frees in {$secondsUntilSlotFrees}s.");
    }
}
