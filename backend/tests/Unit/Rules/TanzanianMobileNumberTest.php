<?php

namespace Tests\Unit\Rules;

use App\Rules\TanzanianMobileNumber;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class TanzanianMobileNumberTest extends TestCase
{
    #[DataProvider('validNumbers')]
    public function test_it_accepts_valid_numbers(string $input): void
    {
        $failed = false;
        (new TanzanianMobileNumber)->validate('phone_number', $input, function () use (&$failed) {
            $failed = true;
        });

        $this->assertFalse($failed);
    }

    public static function validNumbers(): array
    {
        return [
            '07-prefixed' => ['0712345678'],
            '06-prefixed' => ['0612345678'],
        ];
    }

    #[DataProvider('invalidNumbers')]
    public function test_it_rejects_every_other_shape(mixed $input): void
    {
        $failed = false;
        (new TanzanianMobileNumber)->validate('phone_number', $input, function () use (&$failed) {
            $failed = true;
        });

        $this->assertTrue($failed);
    }

    public static function invalidNumbers(): array
    {
        return [
            'missing leading zero' => ['712345678'],
            '255-prefixed' => ['255712345678'],
            'plus-E.164' => ['+255712345678'],
            'too short' => ['071234567'],
            'too long' => ['07123456789'],
            'landline-looking prefix' => ['0212345678'],
            'contains letters' => ['07abcdefgh'],
            'not a string' => [12345678901],
        ];
    }
}
