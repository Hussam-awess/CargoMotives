<?php

namespace App\Services\Gps;

/**
 * A GPS device's name on the provider's own dashboard is often just
 * "<PLATE> <driver name>" or "<PLATE>.<driver name>" (confirmed against
 * real Tracksolid Pro device names — e.g. "T456EFS.JOSEFAT MGOSI",
 * "T579EKP MWINYI") rather than two separate fields. Shared by
 * GpsConnectionController::import() (plate only, at truck-creation time)
 * and TracksolidGpsProvider (plate + driver name, as a fallback for
 * devices with no dedicated driverName API field set) so both read the
 * exact same convention instead of two divergent regexes drifting apart.
 */
class DeviceNameParser
{
    /**
     * @return array{plate: string, driverName: ?string}
     */
    public static function parse(string $rawName): array
    {
        $trimmed = trim($rawName);

        if (! preg_match('/^([A-Za-z0-9]+)(.*)$/', $trimmed, $matches)) {
            return ['plate' => $trimmed, 'driverName' => null];
        }

        $plate = $matches[1];
        $remainder = $matches[2];

        // Only a space or a dot counts as the plate/driver separator
        // (confirmed real examples: "T579EKP MWINYI", "T456EFS.JOSEFAT
        // MGOSI") — anything else immediately after the plate means this
        // isn't a "<PLATE> <driver name>" string at all, most likely a
        // bare device serial/model number like "AT4-SERIAL", which must
        // never be misread as a driver name.
        if ($remainder === '' || ! str_starts_with($remainder, ' ') && ! str_starts_with($remainder, '.')) {
            return ['plate' => $plate, 'driverName' => null];
        }

        $driverName = trim($remainder, " .\t\n\r\0\x0B");

        // A driver's name is letters, never digits. This is what keeps a
        // plate that merely happens to contain spaces ("T 123 ABC") from
        // being read as plate "T" driven by "123 ABC" — real names
        // ("MWINYI", "JOSEFAT MGOSI") always pass, plate fragments never do.
        if ($driverName === '' || preg_match('/\d/', $driverName) || ! preg_match('/\p{L}/u', $driverName)) {
            return ['plate' => $plate, 'driverName' => null];
        }

        return ['plate' => $plate, 'driverName' => $driverName];
    }
}
