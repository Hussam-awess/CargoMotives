<?php

namespace App\Livewire\Admin\Messages;

use App\Models\SupportMessage;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;

/**
 * The standalone Admin<->User Support channel (Phase 10.15) — separate
 * from job-scoped chat. Admin either picks one user (search, same
 * name/phone/email pattern as Admin\Search\Index) and sees + replies to
 * that user's whole thread, or broadcasts one message to every Customer
 * or every Company at once (one SupportMessage row per recipient, so
 * each user's own thread query stays a plain `where('user_id', ...)` —
 * see the migration's own docblock).
 */
#[Layout('layouts.admin')]
class Index extends Component
{
    #[Url]
    public string $query = '';

    public ?int $selectedUserId = null;

    /** '' | 'customer' | 'transporter_company' */
    public string $broadcastTarget = '';

    public string $body = '';

    public ?string $statusMessage = null;

    public function selectUser(int $userId): void
    {
        $this->selectedUserId = $userId;
        $this->broadcastTarget = '';
        $this->statusMessage = null;
    }

    public function selectBroadcast(string $accountType): void
    {
        $this->broadcastTarget = $accountType;
        $this->selectedUserId = null;
        $this->statusMessage = null;
    }

    public function send(): void
    {
        $this->validate(['body' => ['required', 'string', 'max:2000']]);

        if ($this->selectedUserId !== null) {
            $recipients = User::where('id', $this->selectedUserId)->get();
        } elseif ($this->broadcastTarget !== '') {
            $recipients = User::where('account_type', $this->broadcastTarget)->get();
        } else {
            $this->addError('body', 'Choose a user or a broadcast target first.');

            return;
        }

        foreach ($recipients as $recipient) {
            SupportMessage::create([
                'user_id' => $recipient->id,
                'author' => 'admin',
                'admin_id' => Auth::guard('web')->id(),
                'body' => $this->body,
            ]);
        }

        if ($recipients->count() === 1) {
            $recipient = $recipients->first();
            $this->statusMessage = 'Sent to '.($recipient->full_name ?? $recipient->phone_number).'.';
        } else {
            $noun = $this->broadcastTarget === 'customer' ? 'customer' : 'company';
            $this->statusMessage = "Sent to {$recipients->count()} ".str($noun)->plural($recipients->count())->toString().'.';
        }

        $this->body = '';
    }

    public function render()
    {
        $term = trim($this->query);

        return view('livewire.admin.messages.index', [
            'customers' => $term === '' ? collect() : $this->searchUsers($term, 'customer'),
            'companies' => $term === '' ? collect() : $this->searchUsers($term, 'transporter_company'),
            'selectedUser' => $this->selectedUserId === null ? null : User::find($this->selectedUserId),
            'thread' => $this->selectedUserId === null
                ? collect()
                : SupportMessage::where('user_id', $this->selectedUserId)->with('admin')->orderBy('created_at')->get(),
        ]);
    }

    private function searchUsers(string $term, string $accountType): Collection
    {
        return User::where('account_type', $accountType)
            ->where(function ($q) use ($term) {
                $q->where('full_name', 'like', "%{$term}%")
                    ->orWhere('phone_number', 'like', "%{$term}%")
                    ->orWhere('email', 'like', "%{$term}%");
            })
            ->limit(20)
            ->get();
    }
}
