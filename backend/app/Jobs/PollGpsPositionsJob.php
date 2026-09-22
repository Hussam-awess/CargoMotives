<?php

namespace App\Jobs;

use App\Models\GpsConnection;
use App\Models\Truck;
use App\Services\Gps\GpsProviderException;
use App\Services\Gps\GpsProviderManager;
use App\Services\Gps\GpsUnit;
use Illuminate\Bus\Queueable;
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
    // Queueable specifically (not just Dispatchable/InteractsWithQueue,
    // this app's usual job trait set) — Schedule::job() reads $job->queue
    // directly (Illuminate\Console\Scheduling\Schedule::job()), which only
    // Queueable declares. Without it, every scheduled run threw an
    // uncaught "Undefined property: $queue" and aborted before ever
    // fetching a single position — this is why GPS positions silently
    // stopped updating: the fleet map has no live data to poll for if this
    // job never runs.
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle(GpsProviderManager $providers): void
    {
        // Deliberately not just 'connected': a connection that failed on a
        // prior cycle (bad token, or a provider transiently rate-limiting
        // us — both real, observed failure modes) is marked 'error' below,
        // but that must never be permanent. Retrying it every cycle costs
        // nothing extra when it's still broken (same isolated try/catch as
        // before) and lets it self-heal the moment the provider recovers,
        // instead of silently staying dark until a human notices and
        // manually reconnects. 'disconnected' is the one status that must
        // stay untouched — that's the user's own explicit stop.
        GpsConnection::where('status', '!=', 'disconnected')->each(function (GpsConnection $connection) use ($providers) {
            $this->pollConnection($connection, $providers);
        });
    }

    private function pollConnection(GpsConnection $connection, GpsProviderManager $providers): void
    {
        try {
            // Each connection independently records which provider it
            // uses — resolved per-connection, not a single app-wide
            // instance, since two companies can each pick a different one.
            $units = $providers->driver($connection->provider)->listUnits($connection->access_token);
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

            NormalizeGpsPositionJob::dispatch(
                $truck->id,
                $unit->lat,
                $unit->lng,
                $unit->heading,
                $unit->recordedAt,
                $unit->speedKmh,
                $unit->driverName,
            );
        }

        // A successful poll is also the recovery signal: without writing
        // 'connected' back here, a connection that errored once would keep
        // being retried (see handle()'s docblock) and keep updating truck
        // positions again server-side, but the app's own "is GPS connected"
        // check (mobile fleet_screen.dart) filters strictly on
        // status === 'connected' — it would stay stuck showing
        // "Connect GPS" forever even after the provider recovered.
        $connection->update(['status' => 'connected', 'last_synced_at' => now()]);
    }
}
