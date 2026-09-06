<?php

use App\Broadcasting\JobChannel;
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
