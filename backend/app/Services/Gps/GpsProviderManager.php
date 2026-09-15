<?php

namespace App\Services\Gps;

use App\Services\Gps\Traccar\TraccarGpsProvider;
use App\Services\Gps\Tracksolid\TracksolidGpsProvider;
use App\Services\Gps\Wialon\WialonGpsProvider;
use InvalidArgumentException;

/**
 * Resolves the right GpsProvider for a given provider name — needed once
 * a second provider (Traccar) existed alongside Wialon, since each
 * GpsConnection independently records which one it uses
 * (gps_connections.provider) and both the Connect flow and the poll job
 * must call the matching implementation, not a single container-wide
 * instance (Phase 6 bound GpsProvider::class directly to Wialon, which
 * only worked because nothing else existed yet).
 *
 * Deliberately not a Laravel `Manager` subclass: that base class is built
 * around one app-wide "default" driver (right for something like
 * SmsManager, where the whole app sends through one gateway); here every
 * call site already has an explicit provider name in hand (the request
 * body, or the connection row) and never wants a default.
 *
 * Each concrete provider is resolved through the container (not `new`'d
 * directly) so a test can still swap one out with
 * `$this->app->instance(WialonGpsProvider::class, $fake)` exactly as
 * before this class existed.
 */
class GpsProviderManager
{
    public function driver(string $name): GpsProvider
    {
        return match ($name) {
            'wialon' => app(WialonGpsProvider::class),
            'traccar' => app(TraccarGpsProvider::class),
            'tracksolid_pro' => app(TracksolidGpsProvider::class),
            default => throw new InvalidArgumentException("Unsupported GPS provider [{$name}]."),
        };
    }
}
