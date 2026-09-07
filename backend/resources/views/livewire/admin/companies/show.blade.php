<div>
    <a href="{{ route('admin.companies.index') }}" wire:navigate class="text-sm text-slate-500 hover:underline">&larr; Companies</a>

    @if ($statusMessage)
        <div class="mt-2 rounded border border-emerald-300 bg-emerald-50 px-4 py-2 text-sm text-emerald-800">{{ $statusMessage }}</div>
    @endif
    @error('approve') <div class="mt-2 rounded border border-red-300 bg-red-50 px-4 py-2 text-sm text-red-800">{{ $message }}</div> @enderror

    <div class="flex items-start justify-between mt-2 mb-6">
        <div>
            <h1 class="text-xl font-semibold">{{ $company->company_name }}</h1>
            <div class="mt-1"><x-admin.status-badge :status="$company->verification_status" /></div>
        </div>

        @if (in_array($company->verification_status, ['pending', 'flagged_duplicate'], true))
            <div class="flex gap-2">
                <button wire:click="approve" wire:confirm="Approve {{ $company->company_name }}?" class="rounded bg-emerald-600 text-white text-sm px-3 py-1.5 hover:bg-emerald-700">
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

    @if ($company->verification_status === 'rejected' && $company->verification_rejected_reason)
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6 text-sm text-red-800">
            <strong>Rejected:</strong> {{ $company->verification_rejected_reason }}
        </div>
    @endif

    @if ($conflict)
        <div class="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-6">
            <h2 class="text-sm font-semibold text-amber-900 mb-2">Possible duplicate of an existing company</h2>
            <p class="text-sm text-amber-800">
                <a href="{{ route('admin.companies.show', $conflict) }}" wire:navigate class="underline">{{ $conflict->company_name }}</a>
                — registration {{ $conflict->registration_number }}, TIN {{ $conflict->tin }}, currently
                <x-admin.status-badge :status="$conflict->verification_status" />
            </p>
        </div>
    @endif

    <div class="grid grid-cols-2 gap-6">
        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Company</h2>
            <dl class="text-sm space-y-2">
                <div class="flex justify-between"><dt class="text-slate-500">Registration No.</dt><dd>{{ $company->registration_number }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">TIN</dt><dd>{{ $company->tin }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Address</dt><dd>{{ $company->physical_address }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Phone</dt><dd>{{ $company->company_phone }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Email</dt><dd>{{ $company->company_email }}</dd></div>
            </dl>
        </div>

        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Representative</h2>
            <dl class="text-sm space-y-2">
                <div class="flex justify-between"><dt class="text-slate-500">Full name</dt><dd>{{ $company->rep_full_name }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">Position</dt><dd>{{ $company->rep_position }}</dd></div>
                <div class="flex justify-between"><dt class="text-slate-500">NIDA No.</dt><dd>{{ $company->rep_national_id_number }}</dd></div>
            </dl>
        </div>
    </div>

    @if (!empty($company->documents))
        <div class="bg-white border border-slate-200 rounded-lg p-4 mt-6">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Documents</h2>
            <ul class="text-sm space-y-1">
                @foreach ($company->documents as $label => $url)
                    <li><a href="{{ $url }}" target="_blank" class="text-slate-700 underline">{{ ucwords(str_replace('_', ' ', $label)) }}</a></li>
                @endforeach
            </ul>
        </div>
    @endif
</div>
