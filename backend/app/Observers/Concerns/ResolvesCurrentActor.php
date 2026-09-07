<?php

namespace App\Observers\Concerns;

/**
 * The user behind a state change, when there is one. Many state changes
 * this app logs happen outside an authenticated HTTP request entirely — a
 * queued GPS normalizer job, a payment webhook, the Driver Link (which has
 * no User at all, only a scoped token) — so `null` (a system event, per
 * Backend Schema §2.16's "null for system events") is the expected, not
 * exceptional, outcome for those.
 */
trait ResolvesCurrentActor
{
    private function currentActorId(): ?int
    {
        return request()?->user()?->id;
    }
}
