<?php

namespace App\Services\Geo;

use Illuminate\Database\Query\Expression;
use Illuminate\Support\Facades\DB;

/**
 * A lat/lng pair, with the glue needed to write it into a PostGIS
 * `geography(Point,4326)` column and read it back out.
 *
 * Laravel 11+'s Schema\Blueprint has native geography()/geometry() column
 * support, but Eloquent has no matching attribute cast for reading/writing
 * geometry values — so writes go through a raw SQL expression here, and
 * reads go through Job::scopeWithCoordinates()'s ST_X/ST_Y select, rather
 * than adding a third-party spatial package for what's currently just
 * storage (Phase 8's return-load matching is the first thing that will
 * actually run a spatial query against these columns).
 *
 * Values are always validated as numeric by the caller's Form Request
 * before reaching here and are explicitly cast to float, so this is safe
 * against SQL injection despite the string interpolation — there's no path
 * for arbitrary text to reach the raw SQL.
 */
final readonly class GeoPoint
{
    public function __construct(
        public float $lat,
        public float $lng,
    ) {}

    /**
     * A raw SQL expression suitable for use as an Eloquent attribute value
     * on create()/update() — e.g. ['pickup_location' => $point->toInsertExpression()].
     */
    public function toInsertExpression(): Expression
    {
        return DB::raw(sprintf('ST_SetSRID(ST_MakePoint(%F, %F), 4326)::geography', $this->lng, $this->lat));
    }
}
