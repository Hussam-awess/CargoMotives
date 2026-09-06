<?php

namespace App\Services\Settings;

use App\Models\PlatformSetting;
use Illuminate\Support\Facades\Cache;

/**
 * Typed, cached read access to platform_settings (Backend Schema §2.17).
 * Write access (an Admin editing a value) is Phase 9's settings form —
 * nothing before then needs to write these rows, only read them.
 *
 * Cached briefly (not indefinitely): these values change rarely, but a
 * short TTL means an Admin edit (once Phase 9 exists) takes effect within
 * a minute rather than needing a manual cache-bust step.
 */
class PlatformSettings
{
    private const CACHE_TTL_SECONDS = 60;

    public function getInt(string $key, int $default): int
    {
        return (int) $this->getRaw($key, (string) $default);
    }

    public function getFloat(string $key, float $default): float
    {
        return (float) $this->getRaw($key, (string) $default);
    }

    private function getRaw(string $key, string $default): string
    {
        return Cache::remember(
            "platform_setting:{$key}",
            self::CACHE_TTL_SECONDS,
            fn () => PlatformSetting::where('key', $key)->value('value') ?? $default,
        );
    }
}
