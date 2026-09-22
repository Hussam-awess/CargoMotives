<?php

namespace App\Http\Controllers;

use App\Http\Requests\SendMessageRequest;
use App\Http\Resources\MessageResource;
use App\Models\Job;
use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

/**
 * A job's message thread (Backend Schema §2.15) — "the job itself is the
 * conversation," reachable by exactly its two participants: the customer
 * and (once one exists) the assigned company's owner. Deliberately plain
 * REST + refresh-on-open (TRD §4 — messaging is explicitly NOT one of the
 * two WebSocket use cases), and deliberately sits under plain auth:sanctum
 * rather than either role-specific route group, since the same controller
 * serves both a customer and a company hitting the same job's thread.
 */
class MessageController extends Controller
{
    public function index(Request $request, Job $job): AnonymousResourceCollection
    {
        $this->authorizeParticipant($request, $job);

        $messages = $job->messages()->with('sender.transporterCompany')->orderBy('created_at')->get();

        // Opening the thread is what marks the other party's messages
        // read — never the sender's own messages, and never a separate
        // "mark read" action the client has to remember to call.
        $job->messages()
            ->where('sender_user_id', '!=', $request->user()->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return MessageResource::collection($messages);
    }

    public function store(SendMessageRequest $request, Job $job): MessageResource
    {
        $this->authorizeParticipant($request, $job);

        if ($job->assigned_company_id === null) {
            throw ValidationException::withMessages([
                'job_id' => ['Messaging opens once a company is assigned to this job.'],
            ]);
        }

        $message = Message::create([
            'job_id' => $job->id,
            'sender_user_id' => $request->user()->id,
            'body' => $request->validated('body'),
        ]);

        return new MessageResource($message->load('sender.transporterCompany'));
    }

    private function authorizeParticipant(Request $request, Job $job): void
    {
        $userId = $request->user()->id;
        $isParticipant = $job->customer_id === $userId || $job->assignedCompany?->owner_user_id === $userId;

        abort_unless($isParticipant, 404);
    }
}
