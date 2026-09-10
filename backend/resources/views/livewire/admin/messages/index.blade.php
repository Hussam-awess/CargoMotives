<div>
    <h1 class="text-xl font-semibold mb-6">Messages</h1>

    <div class="grid grid-cols-3 gap-6">
        <div class="col-span-1">
            <input
                type="text" wire:model.live.debounce.400ms="query" placeholder="Search a user by name, phone, or email"
                class="w-full rounded border border-slate-300 text-sm px-3 py-2 mb-4"
            >

            <div class="flex gap-2 mb-4">
                <button
                    type="button" wire:click="selectBroadcast('customer')"
                    class="flex-1 text-sm px-3 py-2 rounded border {{ $broadcastTarget === 'customer' ? 'bg-slate-800 text-white border-slate-800' : 'border-slate-300 text-slate-600' }}"
                >
                    All Customers
                </button>
                <button
                    type="button" wire:click="selectBroadcast('transporter_company')"
                    class="flex-1 text-sm px-3 py-2 rounded border {{ $broadcastTarget === 'transporter_company' ? 'bg-slate-800 text-white border-slate-800' : 'border-slate-300 text-slate-600' }}"
                >
                    All Companies
                </button>
            </div>

            @if (trim($query) !== '')
                <div class="mb-2">
                    <h2 class="text-xs font-semibold text-slate-500 mb-1 uppercase">Customers</h2>
                    <div class="bg-white border border-slate-200 rounded-lg divide-y divide-slate-100">
                        @forelse ($customers as $customer)
                            <button
                                type="button" wire:click="selectUser({{ $customer->id }})"
                                class="w-full text-left px-3 py-2 text-sm hover:bg-slate-50 {{ $selectedUserId === $customer->id ? 'bg-slate-100' : '' }}"
                            >
                                <div class="font-medium">{{ $customer->full_name ?? $customer->phone_number }}</div>
                                <div class="text-slate-500 text-xs">{{ $customer->phone_number }} &middot; {{ $customer->email }}</div>
                            </button>
                        @empty
                            <div class="px-3 py-4 text-center text-slate-400 text-xs">No matching customers.</div>
                        @endforelse
                    </div>
                </div>

                <div>
                    <h2 class="text-xs font-semibold text-slate-500 mb-1 uppercase">Companies</h2>
                    <div class="bg-white border border-slate-200 rounded-lg divide-y divide-slate-100">
                        @forelse ($companies as $company)
                            <button
                                type="button" wire:click="selectUser({{ $company->id }})"
                                class="w-full text-left px-3 py-2 text-sm hover:bg-slate-50 {{ $selectedUserId === $company->id ? 'bg-slate-100' : '' }}"
                            >
                                <div class="font-medium">{{ $company->full_name ?? $company->phone_number }}</div>
                                <div class="text-slate-500 text-xs">{{ $company->phone_number }} &middot; {{ $company->email }}</div>
                            </button>
                        @empty
                            <div class="px-3 py-4 text-center text-slate-400 text-xs">No matching companies.</div>
                        @endforelse
                    </div>
                </div>
            @endif
        </div>

        <div class="col-span-2">
            @if ($selectedUser)
                <div class="mb-3 text-sm text-slate-500">
                    Thread with <span class="font-medium text-slate-800">{{ $selectedUser->full_name ?? $selectedUser->phone_number }}</span>
                </div>
                <div class="bg-white border border-slate-200 rounded-lg p-4 mb-4 max-h-96 overflow-y-auto space-y-3">
                    @forelse ($thread as $message)
                        <div class="flex {{ $message->author === 'admin' ? 'justify-end' : 'justify-start' }}">
                            <div class="max-w-sm rounded-lg px-3 py-2 text-sm {{ $message->author === 'admin' ? 'bg-slate-800 text-white' : 'bg-slate-100 text-slate-800' }}">
                                <div>{{ $message->body }}</div>
                                <div class="text-xs opacity-60 mt-1">{{ $message->created_at->format('d M, H:i') }}</div>
                            </div>
                        </div>
                    @empty
                        <div class="text-center text-slate-400 text-sm py-6">No messages yet.</div>
                    @endforelse
                </div>
            @elseif ($broadcastTarget !== '')
                <div class="mb-3 text-sm text-slate-500">
                    Broadcasting to <span class="font-medium text-slate-800">{{ $broadcastTarget === 'customer' ? 'all Customers' : 'all Companies' }}</span>
                </div>
            @else
                <div class="text-slate-400 text-sm mb-4">Search and pick a user, or choose a broadcast target, to compose a message.</div>
            @endif

            @if ($selectedUser || $broadcastTarget !== '')
                <textarea
                    wire:model="body" rows="3" placeholder="Write a message…"
                    class="w-full rounded border border-slate-300 text-sm px-3 py-2 mb-2"
                ></textarea>
                @error('body') <div class="text-red-600 text-xs mb-2">{{ $message }}</div> @enderror

                <button type="button" wire:click="send" class="bg-slate-800 text-white text-sm px-4 py-2 rounded">Send</button>

                @if ($statusMessage)
                    <span class="text-emerald-600 text-sm ml-3">{{ $statusMessage }}</span>
                @endif
            @endif
        </div>
    </div>
</div>
