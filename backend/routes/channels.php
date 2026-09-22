<?php

use App\Broadcasting\AwardLocationChannel;
use App\Broadcasting\JobChannel;
use App\Broadcasting\JobLocationChannel;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

// Live bid updates (TRD §4) — only the job's own customer watches this,
// per the documented use case ("while a customer is looking at a job's
// bid list"). Not opened up to companies watching their own bid's status;
// nothing in the docs calls for that, and extending scope here would be
// guessing at a requirement rather than building one. Class-based (see
// App\Broadcasting\JobChannel) rather than an inline closure, specifically
// so the rule is unit-testable without needing a live Pusher-protocol
// broadcaster driver wired up just to exercise it.
Broadcast::channel('job.{jobId}', JobChannel::class);

// Live GPS (TRD §5.2) — a separate channel from job.{jobId} above because
// its audience is broader: both the customer AND the assigned company
// watch the same truck's position, not just the customer.
Broadcast::channel('job.{jobId}.location', JobLocationChannel::class);

// Multi-Company Split Awards epic: one company's own award-scoped live
// GPS — a separate channel per award (not job.{jobId}.location) since two
// unrelated companies' positions must never share one private channel.
Broadcast::channel('award.{awardId}.location', AwardLocationChannel::class);
