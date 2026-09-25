<?php

namespace App\Services\Jobs;

use App\Models\DriverLink;
use App\Models\Job;
use App\Models\JobAward;
use App\Models\ProofOfDelivery;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

/**
 * The one place a ProofOfDelivery row gets created and its job/award marked
 * 'delivered' — extracted from JobAssignmentController::submitProofOfDelivery()
 * and DriverLinkPageController::submitProofOfDelivery(), which used to
 * duplicate this transaction identically. Also the entry point for
 * AutoCompleteStuckDeliveries, which calls it with an empty $photoKeys and
 * $isSystemGenerated = true — the caller (both controllers) is still
 * responsible for its own permit/status/photo validation before reaching
 * here; this service only ever performs the write.
 */
class ProofOfDeliveryService
{
    /**
     * @param  array<int, string>  $photoKeys
     */
    public function submit(
        Job $job,
        ?JobAward $award,
        DriverLink $link,
        array $photoKeys,
        ?string $recipientName,
        ?string $notes,
        bool $isSystemGenerated = false,
    ): ProofOfDelivery {
        return DB::transaction(function () use ($job, $award, $link, $photoKeys, $recipientName, $notes, $isSystemGenerated) {
            $pod = ProofOfDelivery::create([
                'job_id' => $job->id,
                'job_award_id' => $award?->id,
                'driver_id' => $link->driver_id,
                'driver_link_id' => $link->id,
                'photo_urls' => $photoKeys,
                'recipient_name' => $recipientName,
                'notes' => $notes,
                'is_system_generated' => $isSystemGenerated,
            ]);

            /** @var Model $statusHolder */
            $statusHolder = $award ?? $job;
            $statusHolder->update(['status' => 'delivered']);

            if ($link->status !== 'used') {
                $link->update(['status' => 'used', 'used_at' => now()]);
            }

            return $pod;
        });
    }
}
