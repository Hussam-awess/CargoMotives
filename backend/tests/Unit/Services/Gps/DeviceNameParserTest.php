<?php

namespace Tests\Unit\Services\Gps;

use App\Services\Gps\DeviceNameParser;
use Tests\TestCase;

class DeviceNameParserTest extends TestCase
{
    public function test_splits_a_plate_and_driver_name_separated_by_a_space(): void
    {
        $this->assertSame(
            ['plate' => 'T579EKP', 'driverName' => 'MWINYI'],
            DeviceNameParser::parse('T579EKP MWINYI')
        );
    }

    public function test_splits_a_plate_and_driver_name_separated_by_a_dot(): void
    {
        $this->assertSame(
            ['plate' => 'T456EFS', 'driverName' => 'JOSEFAT MGOSI'],
            DeviceNameParser::parse('T456EFS.JOSEFAT MGOSI')
        );
    }

    public function test_a_plate_only_name_has_no_driver(): void
    {
        $this->assertSame(
            ['plate' => 'T334DCR', 'driverName' => null],
            DeviceNameParser::parse('T334DCR')
        );
    }

    public function test_trims_surrounding_whitespace(): void
    {
        $this->assertSame(
            ['plate' => 'T111APW', 'driverName' => 'JUMA'],
            DeviceNameParser::parse('  T111APW   JUMA  ')
        );
    }

    /**
     * A real device on this account is named "AT4-SERIAL" — a bare model/
     * serial number, not a plate at all. Only a space or a dot counts as
     * the plate/driver separator, so a hyphen (or anything else) must never
     * be misread as one.
     */
    public function test_a_hyphen_separated_serial_number_has_no_driver(): void
    {
        $this->assertSame(
            ['plate' => 'AT4', 'driverName' => null],
            DeviceNameParser::parse('AT4-SERIAL')
        );
    }

    /**
     * The failure mode that matters once this runs for every provider, not
     * just Tracksolid: a fleet that writes its plates with spaces must
     * never have the rest of its own plate read back as a driver's name.
     */
    public function test_a_space_separated_plate_is_not_mistaken_for_a_driver(): void
    {
        $this->assertSame(
            ['plate' => 'T', 'driverName' => null],
            DeviceNameParser::parse('T 123 ABC')
        );
    }

    public function test_a_name_containing_any_digit_is_never_treated_as_a_driver(): void
    {
        $this->assertNull(DeviceNameParser::parse('T456EFS UNIT 2')['driverName']);
    }
}
