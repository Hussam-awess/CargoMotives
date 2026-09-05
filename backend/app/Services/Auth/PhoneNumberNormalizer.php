<?php

namespace App\Services\Auth;

use InvalidArgumentException;

/**
 * Normalizes Tanzanian phone numbers to one canonical form (+255XXXXXXXXX)
 * before they ever touch the `phone_number` unique constraint or an OTP
 * lookup.
 *
 * Why this exists: `users.phone_number` is unique (Backend Schema §2.1), but
 * the same real number can arrive in several shapes — 0712345678 (local),
 * 255712345678 (no +), or +255712345678 — depending on how a user types it
 * or what a device autofills. Without normalizing first, those would be
 * treated as three different accounts, silently defeating the uniqueness
 * check and the "one account per phone" assumption the whole auth flow
 * relies on.
 */
class PhoneNumberNormalizer
{
    private const COUNTRY_CODE = '255';

    /**
     * @throws InvalidArgumentException if the input doesn't look like a
     *                                  Tanzanian mobile number once stripped of formatting.
     */
    public static function normalize(string $rawNumber): string
    {
        $digits = preg_replace('/\D+/', '', $rawNumber);

        $nationalNumber = match (true) {
            // 0712345678 -> 712345678
            str_starts_with($digits, '0') && strlen($digits) === 10 => substr($digits, 1),
            // 255712345678 -> 712345678
            str_starts_with($digits, self::COUNTRY_CODE) && strlen($digits) === 12 => substr($digits, 3),
            // 712345678 (already national, no leading 0)
            strlen($digits) === 9 => $digits,
            default => null,
        };

        if ($nationalNumber === null || ! preg_match('/^[67]\d{8}$/', $nationalNumber)) {
            throw new InvalidArgumentException("\"{$rawNumber}\" is not a recognizable Tanzanian mobile number.");
        }

        return '+'.self::COUNTRY_CODE.$nationalNumber;
    }
}
