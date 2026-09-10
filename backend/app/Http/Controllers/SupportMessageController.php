<?php

namespace App\Http\Controllers;

use App\Http\Requests\SendSupportMessageRequest;
use App\Http\Resources\SupportMessageResource;
use App\Models\SupportMessage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * A user's own Support thread with Admin (Phase 10.15) — always scoped to
 * `auth()->user()->id`, never another user's, so unlike MessageController
 * there's no participant check to make: the route parameter IS the
 * caller, not a shared resource two different users both touch.
 */
class SupportMessageController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $messages = SupportMessage::where('user_id', $request->user()->id)->orderBy('created_at')->get();

        return SupportMessageResource::collection($messages);
    }

    public function store(SendSupportMessageRequest $request): SupportMessageResource
    {
        $message = SupportMessage::create([
            'user_id' => $request->user()->id,
            'author' => 'user',
            'body' => $request->validated('body'),
        ]);

        return new SupportMessageResource($message);
    }
}
