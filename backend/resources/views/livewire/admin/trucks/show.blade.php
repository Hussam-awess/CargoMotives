<div>
    <a href="{{ route('admin.trucks.index') }}" wire:navigate class="text-sm text-slate-500 hover:underline">&larr; Trucks</a>

    @if ($statusMessage)
        <div class="mt-2 rounded border border-emerald-300 bg-emerald-50 px-4 py-2 text-sm text-emerald-800">{{ $statusMessage }}</div>
    @endif

    <div class="flex items-start justify-between mt-2 mb-6">
        <div>
            <h1 class="text-xl font-semibold">{{ $truck->registration_number }}</h1>
            <div class="mt-1 flex items-center gap-3">
                <x-admin.status-badge :status="$truck->verification_status" />
                <span class="text-slate-300">|</span>
                <x-admin.status-badge :status="$truck->gps_status" />
            </div>
        </div>

        @if ($truck->verification_status === 'pending')
            <div class="flex gap-2">
                <button wire:click="approve" wire:confirm="Approve {{ $truck->registration_number }}?" class="rounded bg-emerald-600 text-white text-sm px-3 py-1.5 hover:bg-emerald-700">
                    Approve
                </button>
                <button wire:click="$set('showRejectForm', true)" class="rounded border border-red-300 text-red-700 text-sm px-3 py-1.5 hover:bg-red-50">
                    Reject
                </button>
            </div>
        @endif
    </div>

    @if ($showRejectForm)
        <div class="bg-white border border-red-200 rounded-lg p-4 mb-6">
            <label class="block text-sm font-medium text-slate-700 mb-1">Reason for rejection</label>
            <textarea wire:model="rejectReason" rows="2" class="w-full rounded border border-slate-300 text-sm px-3 py-2"></textarea>
            @error('rejectReason') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
            <div class="mt-2 flex gap-2">
                <button wire:click="reject" class="rounded bg-red-600 text-white text-sm px-3 py-1.5 hover:bg-red-700">Confirm rejection</button>
                <button wire:click="$set('showRejectForm', false)" class="text-sm text-slate-500 hover:underline">Cancel</button>
            </div>
        </div>
    @endif

    @if ($truck->verification_status === 'rejected' && $truck->verification_rejected_reason)
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6 text-sm text-red-800">
            <strong>Rejected:</strong> {{ $truck->verification_rejected_reason }}
        </div>
    @endif

    <div class="bg-white border border-slate-200 rounded-lg p-4">
        <h2 class="text-sm font-semibold text-slate-500 mb-3">Truck</h2>
        <dl class="text-sm space-y-2">
            <div class="flex justify-between"><dt class="text-slate-500">Company</dt><dd>
                <a href="{{ route('admin.companies.show', $truck->company) }}" wire:navigate class="underline">{{ $truck->company?->company_name }}</a>
            </dd></div>
            <div class="flex justify-between"><dt class="text-slate-500">Make/Model</dt><dd>{{ $truck->make_model }}</dd></div>
            <div class="flex justify-between"><dt class="text-slate-500">Vehicle type</dt><dd>{{ $truck->vehicle_type }}</dd></div>
            <div class="flex justify-between"><dt class="text-slate-500">Capacity</dt><dd>{{ $truck->capacity_tons }} tons</dd></div>
        </dl>
    </div>

    @if (!empty($truck->documents))
        <div class="bg-white border border-slate-200 rounded-lg p-4 mt-6">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Documents</h2>
            <ul class="text-sm space-y-1">
                @foreach (\Illuminate\Support\Arr::flatten([$truck->documents]) as $url)
                    @if (is_string($url))
                        <li><a href="{{ $url }}" target="_blank" class="text-slate-700 underline">{{ $url }}</a></li>
                    @endif
                @endforeach
            </ul>
        </div>
    @endif
</div>
