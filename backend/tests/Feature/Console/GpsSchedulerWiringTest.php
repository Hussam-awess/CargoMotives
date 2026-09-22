<?php

namespace Tests\Feature\Console;

use App\Jobs\PollGpsPositionsJob;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

/**
 * Pins a real regression: PollGpsPositionsJob is scheduled via
 * bootstrap/app.php's `$schedule->job(new PollGpsPositionsJob)`, not
 * `$schedule->command(...)` like every other scheduled task here.
 * Schedule::job() reads $job->queue directly, which only the Queueable
 * trait declares — this job was missing it (matching this codebase's usual
 * Dispatchable/InteractsWithQueue/SerializesModels-only convention for
 * *dispatched* jobs, which never hits that code path). Every scheduled run
 * silently threw "Undefined property: $queue" and aborted before ever
 * fetching a single position — live GPS data on the fleet map stopped
 * updating entirely with no error visible anywhere except the Laravel log.
 */
class GpsSchedulerWiringTest extends TestCase
{
    use RefreshDatabase;

    public function test_poll_gps_positions_job_is_actually_dispatched_by_the_scheduler(): void
    {
        Queue::fake();

        Artisan::call('schedule:run');

        Queue::assertPushed(PollGpsPositionsJob::class);
    }
}
