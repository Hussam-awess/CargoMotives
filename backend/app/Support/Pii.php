<?php

namespace App\Support;

/**
 * Masks personal identifiers before they reach a log line. Logs are
 * retained, shipped to log tooling, and read by people who don't need a
 * user's full phone number or email to debug a delivery failure — the last
 * few characters are enough to correlate with a support request.
 */
final class Pii
{
    public static function maskPhone(?string $phone): string
    {
        if ($phone === null || $phone === '') {
            return '';
        }

        return str_repeat('*', max(0, strlen($phone) - 3)).substr($phone, -3);
    }

    public static function maskEmail(?string $email): string
    {
        if ($email === null || ! str_contains($email, '@')) {
            return '';
        }

        [$local, $domain] = explode('@', $email, 2);

        return substr($local, 0, 1).str_repeat('*', max(1, strlen($local) - 1)).'@'.$domain;
    }
}
