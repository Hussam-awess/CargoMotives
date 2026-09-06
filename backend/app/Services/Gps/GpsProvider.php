<?php

namespace App\Services\Gps;

/**
 * Contract every concrete GPS provider integration implements (TRD §5:
 * "build direct, concrete integrations for the providers actually being
 * supported... not behind an elaborate plugin abstraction"). This
 * interface is intentionally thin — one method, because Wialon's real API
 * shape (and the two things this app actually needs a provider for:
 * listing vehicles to import, and refreshing their positions on a poll)
 * both reduce to "give me every unit this account can see, with whatever
 * position each currently has."
 *
 * @throws GpsProviderException on an invalid token, an unreachable
 *                              provider, or an unexpected response.
 */
interface GpsProvider
{
    /**
     * @return array<int, GpsUnit>
     */
    public function listUnits(string $accessToken): array;
}
