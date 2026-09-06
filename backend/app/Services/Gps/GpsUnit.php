<?php

namespace App\Services\Gps;

use Carbon\CarbonImmutable;

/**
 * One vehicle as reported by a GPS provider, normalized to a common shape
 * (TRD §5.2: "a queued normalizer job turns the provider-specific payload
 * into a common shape") — every concrete GpsProvider implementation
 * returns these, so nothing downstream (the Connect flow, the poll job)
 * ever touches a provider's raw response format.
 */
final readonly class GpsUnit
{
    public function __construct(
        public string $unitId,
        public string $name,
        public ?float $lat,
        public ?float $lng,
        public ?float $heading,
        public ?CarbonImmutable $recordedAt,
    ) {}

    public function hasPosition(): bool
    {
        return $this->lat !== null && $this->lng !== null;
    }
}
