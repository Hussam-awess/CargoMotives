<div>
    <a href="{{ route('admin.jobs.index') }}" wire:navigate class="text-sm text-slate-500 hover:underline">&larr; Jobs</a>

    <div class="flex items-start justify-between mt-2 mb-6">
        <div>
            <h1 class="text-xl font-semibold">Job #{{ $job->id }}</h1>
            <div class="mt-1"><x-admin.status-badge :status="$job->status" /></div>
        </div>
    </div>

    <div class="grid grid-cols-2 gap-6 mb-6">
        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Route</h2>
            <dl class="text-sm space-y-2">
                <div class="flex justify-between"><dt class="text-slate-500">Pickup</dt><dd class="text-right">{{ $job->pickup_address }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Dropoff</dt><dd class="text-right">{{ $job->dropoff_address }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Container</dt><dd>{{ $job->container_type }} / {{ $job->container_size }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Customer</dt><dd>{{ $job->customer?->full_name }}</dd></div>
            </dl>
        </div>

        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Assignment</h2>
            @if ($job->assignedCompany)
                <dl class="text-sm space-y-2">
                    <div class="flex justify-between"><dt class="text-slate-500">Company</dt><dd>
                        <a href="{{ route('admin.companies.show', $job->assignedCompany) }}" wire:navigate class="underline">{{ $job->assignedCompany->company_name }}</a>
                    </dd></div>
                    <div class="flex justify-between"><dt class="text-slate-500">Truck</dt><dd>{{ $job->assignedTruck?->registration_number ?? '—' }}</dd></div>
                    <div class="flex justify-between"><dt class="text-slate-500">Driver</dt><dd>{{ $job->assignedDriver?->full_name ?? '—' }}</dd></div>
                    <div class="flex justify-between"><dt class="text-slate-500">Agreed price</dt><dd>TZS {{ number_format($job->agreed_price) }}</dd></div>
                </dl>
            @else
                <p class="text-sm text-slate-400">Not yet assigned.</p>
            @endif
        </div>
    </div>

    @if ($job->disputes->isNotEmpty())
        <div class="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-6">
            <h2 class="text-sm font-semibold text-amber-900 mb-2">Disputes</h2>
            @foreach ($job->disputes as $dispute)
                <div class="text-sm text-amber-800 flex items-center justify-between py-1">
                    <span>{{ \Illuminate\Support\Str::limit($dispute->reason, 60) }}</span>
                    <a href="{{ route('admin.disputes.show', $dispute) }}" wire:navigate class="underline"><x-admin.status-badge :status="$dispute->status" /></a>
                </div>
            @endforeach
        </div>
    @endif

    @if ($job->proofOfDelivery)
        <div class="bg-white border border-slate-200 rounded-lg p-4 mb-6">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Proof of delivery</h2>
            <dl class="text-sm space-y-2">
                <div class="flex justify-between"><dt class="text-slate-500">Recipient</dt><dd>{{ $job->proofOfDelivery->recipient_name ?? '—' }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Confirmed by customer</dt><dd>{{ $job->proofOfDelivery->confirmed_by_customer_at?->format('Y-m-d H:i') ?? 'Not yet' }}</dd></div>
            </dl>
            @if (!empty($job->proofOfDelivery->photo_urls))
                <div class="flex gap-2 mt-3">
                    @foreach ($job->proofOfDelivery->photo_urls as $url)
                        <a href="{{ $url }}" target="_blank"><img src="{{ $url }}" class="w-20 h-20 object-cover rounded border border-slate-200"></a>
                    @endforeach
                </div>
            @endif
        </div>
    @endif

    <div class="bg-white border border-slate-200 rounded-lg p-4 mb-6">
        <h2 class="text-sm font-semibold text-slate-500 mb-3">Bids ({{ $job->bids->count() }})</h2>
        @forelse ($job->bids as $bid)
            <div class="flex items-center justify-between py-2 border-b border-slate-100 last:border-0 text-sm">
                <span>{{ $bid->company?->company_name }} &middot; TZS {{ number_format($bid->price) }}</span>
                <x-admin.status-badge :status="$bid->status" />
            </div>
        @empty
            <p class="text-sm text-slate-400">No bids yet.</p>
        @endforelse
    </div>

    <div class="bg-white border border-slate-200 rounded-lg p-4">
        <h2 class="text-sm font-semibold text-slate-500 mb-3">Timeline</h2>
        @forelse ($timeline as $entry)
            <div class="flex items-start justify-between py-2 border-b border-slate-100 last:border-0 text-sm">
                <div>
                    <span class="font-medium">{{ ucwords(str_replace('_', ' ', $entry->action)) }}</span>
                    @if ($entry->metadata)
                        <span class="text-slate-500"> — {{ json_encode($entry->metadata) }}</span>
                    @endif
                    <div class="text-slate-400 text-xs mt-0.5">{{ $entry->actor?->full_name ?? 'System' }}</div>
                </div>
                <span class="text-slate-400 text-xs whitespace-nowrap">{{ $entry->created_at->format('Y-m-d H:i:s') }}</span>
            </div>
        @empty
            <p class="text-sm text-slate-400">No activity logged yet.</p>
        @endforelse
    </div>
</div>
