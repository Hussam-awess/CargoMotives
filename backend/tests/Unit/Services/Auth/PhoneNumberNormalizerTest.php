<?php

namespace Tests\Unit\Services\Auth;

use App\Services\Auth\PhoneNumberNormalizer;
use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class PhoneNumberNormalizerTest extends TestCase
{
    #[DataProvider('validNumbers')]
    public function test_it_normalizes_valid_tanzanian_numbers(string $input, string $expected): void
    {
        $this->assertSame($expected, PhoneNumberNormalizer::normalize($input));
    }

    public static function validNumbers(): array
    {
        return [
            'local with leading zero' => ['0712345678', '+255712345678'],
            'country code, no plus' => ['255712345678', '+255712345678'],
            'already E.164' => ['+255712345678', '+255712345678'],
            'with spaces and dashes' => ['+255 712-345-678', '+255712345678'],
            'national number without leading zero' => ['712345678', '+255712345678'],
            '06-prefixed mobile' => ['0612345678', '+255612345678'],
        ];
    }

    #[DataProvider('invalidNumbers')]
    public function test_it_rejects_unrecognizable_numbers(string $input): void
    {
        $this->expectException(InvalidArgumentException::class);
        PhoneNumberNormalizer::normalize($input);
    }

    public static function invalidNumbers(): array
    {
        return [
            'too short' => ['12345'],
            'landline-looking prefix' => ['0212345678'],
            'US number' => ['+14155552671'],
            'empty' => [''],
        ];
    }
}
