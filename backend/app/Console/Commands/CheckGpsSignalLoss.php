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
 *
 * Two distinct "gone quiet" cases, both caught here (a Phase 10 audit
 * found only the first was actually handled):
 *  1. A truck that WAS sending positions and stopped — last_known_at is
 *     set but older than the cutoff.
 *  2. A truck marked GPS-connected at assignment (optimistically set to
 *     'ok' — see JobAssignmentService) that never sends a single real
 *     position at all — last_known_at stays NULL forever, which a plain
 *     `last_known_at < cutoff` comparison can never match (SQL comparisons
 *     against NULL are neither true nor false). gps_tracking_started_at
 *     exists specifically to give this case something to measure elapsed
 *     time against instead.
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
            ->where(function ($query) use ($cutoff) {
                $query->whereHas('assignedTruck', fn ($q) => $q->where('last_known_at', '<', $cutoff))
                    ->orWhere(function ($query) use ($cutoff) {
                        $query->whereHas('assignedTruck', fn ($q) => $q->whereNull('last_known_at'))
                            ->where('gps_tracking_started_at', '<', $cutoff);
                    });
            })
            ->update(['gps_signal_status' => 'lost']);

        if ($affected > 0) {
            $this->info("Marked {$affected} job(s) as GPS signal lost.");
        }

        return self::SUCCESS;
    }
}
