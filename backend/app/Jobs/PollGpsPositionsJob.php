<?php

namespace App\Jobs;

use App\Models\GpsConnection;
use App\Models\Truck;
use App\Services\Gps\GpsProvider;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsUnit;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * The "poll" stage of the async GPS pipeline (TRD §5.2) for poll-only
 * providers (Wialon has no outbound webhook in this integration — see
 * WialonGpsProvider's docblock). Scheduled roughly every minute (see
 * bootstrap/app.php's withSchedule); does no normalization itself, only
 * fetches and dispatches one NormalizeGpsPositionJob per unit with a
 * position — keeping this job fast and letting a slow/failing normalizer
 * retry independently per-truck.
 *
 * One connection's failure (bad token, provider outage) is isolated to
 * that connection (TRD §5.3: GPS being down must never cascade) — it's
 * marked 'error' and the cycle moves on to the next company.
 */
class PollGpsPositionsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, SerializesModels;

    public function handle(GpsProvider $provider): void
    {
        GpsConnection::where('status', 'connected')->each(function (GpsConnection $connection) use ($provider) {
            $this->pollConnection($connection, $provider);
        });
    }

    private function pollConnection(GpsConnection $connection, GpsProvider $provider): void
    {
        try {
            $units = $provider->listUnits($connection->access_token);
        } catch (GpsProviderException $e) {
            $connection->update(['status' => 'error']);
            Log::warning('GPS poll failed for a connection', [
                'gps_connection_id' => $connection->id,
                'provider' => $connection->provider,
                'error' => $e->getMessage(),
            ]);

            return;
        }

        $trucksByUnitId = Truck::where('gps_connection_id', $connection->id)
            ->whereNotNull('gps_unit_id')
            ->get()
            ->keyBy('gps_unit_id');

        foreach ($units as $unit) {
            /** @var GpsUnit $unit */
            $truck = $trucksByUnitId->get($unit->unitId);

            if ($truck === null || ! $unit->hasPosition()) {
                continue;
            }

            NormalizeGpsPositionJob::dispatch($truck->id, $unit->lat, $unit->lng, $unit->heading, $unit->recordedAt);
        }

        $connection->update(['last_synced_at' => now()]);
    }
}
