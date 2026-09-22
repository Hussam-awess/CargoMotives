<?php

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

/**
 * Restricts a phone-number *input* field to the one shape the app now asks
 * for everywhere it collects one: 10 digits, starting with "0" (e.g.
 * 0712345678). PhoneNumberNormalizer stays more lenient (it also accepts
 * +255/255-prefixed forms) since it's the read side for already-stored
 * data; this rule is the write-side gate that stops any other shape from
 * being submitted in the first place.
 */
class TanzanianMobileNumber implements ValidationRule
{
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (! is_string($value) || ! preg_match('/^0[67]\d{8}$/', $value)) {
            $fail('Enter a valid 10-digit phone number starting with 0 (e.g. 0712345678).');
        }
    }
}
