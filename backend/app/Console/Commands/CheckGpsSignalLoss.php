<?php

namespace App\Console\Commands;

use App\Models\Job;
use Illuminate\Console\Command;

/**
 * Flips a trackable job's gps_signal_status from 'ok' to 'lost' once its
 * truck's last position is older than the configured threshold (TRD
 * §5.3's "GPS signal unavailable" state — not a frozen/misleading marker).
 *
 * Only ever moves ok -> lost here; the reverse (lost -> ok) happens the
 * instant a fresh position arrives (NormalizeGpsPositionJob), so this
 * command doesn't need to check for recovery itself.
 */
class CheckGpsSignalLoss extends Command
{
    protected $signature = 'gps:check-signal-loss';

    protected $description = "Mark trackable jobs 'lost' when their truck's GPS feed has gone quiet";

    public function handle(): int
    {
        $thresholdMinutes = (int) config('gps.signal_lost_after_minutes', 10);
        $cutoff = now()->subMinutes($thresholdMinutes);

        $affected = Job::where('gps_tracking_active', true)
            ->where('gps_signal_status', 'ok')
            ->whereHas('assignedTruck', fn ($query) => $query->where('last_known_at', '<', $cutoff))
            ->update(['gps_signal_status' => 'lost']);

        if ($affected > 0) {
            $this->info("Marked {$affected} job(s) as GPS signal lost.");
        }

        return self::SUCCESS;
    }
}
