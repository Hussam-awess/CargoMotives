<?php

namespace App\Services\Auth;

use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * The label a new Sanctum token is stored under — what Settings > Active
 * sessions shows the user, so they can tell their own phone apart from a
 * device they don't recognize. Client-supplied, so it's display-only text:
 * stripped, trimmed and length-capped, never trusted for anything else.
 */
final class DeviceName
{
    private const FALLBACK = 'Mobile app';

    public static function from(Request $request): string
    {
        return self::sanitize($request->input('device_name'));
    }

    public static function sanitize(mixed $raw): string
    {
        $name = is_string($raw) ? trim(strip_tags($raw)) : '';

        return $name === '' ? self::FALLBACK : Str::limit($name, 60, '');
    }
}
