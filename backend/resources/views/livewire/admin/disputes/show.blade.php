<div>
    <a href="{{ route('admin.disputes.index') }}" wire:navigate class="text-sm text-slate-500 hover:underline">&larr; Disputes</a>

    <div class="flex items-start justify-between mt-2 mb-6">
        <div>
            <h1 class="text-xl font-semibold">Dispute on <a href="{{ route('admin.jobs.show', $dispute->job) }}" wire:navigate class="underline">Job #{{ $dispute->job_id }}</a></h1>
            <div class="mt-1"><x-admin.status-badge :status="$dispute->status" /></div>
        </div>

        @if ($dispute->status === 'open')
            <button wire:click="markUnderReview" class="rounded border border-slate-300 text-sm px-3 py-1.5 hover:bg-slate-50">
                Mark under review
            </button>
        @endif
    </div>

    <div class="bg-white border border-slate-200 rounded-lg p-4 mb-6">
        <h2 class="text-sm font-semibold text-slate-500 mb-2">Reported problem</h2>
        <p class="text-sm">{{ $dispute->reason }}</p>
        <p class="text-xs text-slate-400 mt-2">Raised by {{ $dispute->raisedBy?->full_name }} on {{ $dispute->created_at->format('Y-m-d H:i') }}</p>
    </div>

    <div class="grid grid-cols-2 gap-6 mb-6">
        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Evidence: Proof of delivery</h2>
            @if ($dispute->job->proofOfDelivery)
                <dl class="text-sm space-y-2">
                    <div class="flex justify-between"><dt class="text-slate-500">Recipient</dt><dd>{{ $dispute->job->proofOfDelivery->recipient_name ?? '—' }}</dd></div>
                    <div class="flex justify-between"><dt class="text-slate-500">Notes</dt><dd>{{ $dispute->job->proofOfDelivery->notes ?? '—' }}</dd></div>
                </dl>
                @if (!empty($dispute->job->proofOfDelivery->photo_urls))
                    <div class="flex gap-2 mt-3">
                        @foreach ($dispute->job->proofOfDelivery->photo_urls as $url)
                            <a href="{{ $url }}" target="_blank"><img src="{{ $url }}" class="w-20 h-20 object-cover rounded border border-slate-200"></a>
                        @endforeach
                    </div>
                @endif
            @else
                <p class="text-sm text-slate-400">No proof of delivery on file.</p>
            @endif
        </div>

        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Evidence: GPS history</h2>
            @if ($dispute->job->locationSnapshots->isNotEmpty())
                <p class="text-sm text-slate-600">{{ $dispute->job->locationSnapshots->count() }} route-replay position(s) recorded for this job.</p>
                <p class="text-xs text-slate-400 mt-1">
                    First: {{ $dispute->job->locationSnapshots->min('recorded_at')?->format('Y-m-d H:i') }} &middot;
                    Last: {{ $dispute->job->locationSnapshots->max('recorded_at')?->format('Y-m-d H:i') }}
                </p>
            @else
                <p class="text-sm text-slate-400">No GPS history was recorded for this job.</p>
            @endif
        </div>
    </div>

    @if ($dispute->status === 'resolved')
        <div class="bg-emerald-50 border border-emerald-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-emerald-900 mb-1">Resolution</h2>
            <p class="text-sm text-emerald-800">{{ $dispute->resolution_note }}</p>
            <p class="text-xs text-emerald-600 mt-1">Resolved {{ $dispute->resolved_at?->format('Y-m-d H:i') }}</p>
        </div>
    @else
        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-2">Resolve this dispute</h2>
            <textarea wire:model="resolutionNote" rows="3" placeholder="What was decided, and why" class="w-full rounded border border-slate-300 text-sm px-3 py-2"></textarea>
            @error('resolutionNote') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
            <button wire:click="resolve" wire:confirm="Resolve this dispute?" class="mt-2 rounded bg-slate-900 text-white text-sm px-3 py-1.5 hover:bg-slate-800">
                Resolve
            </button>
        </div>
    @endif
</div>
