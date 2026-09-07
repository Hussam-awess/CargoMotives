<div>
    <a href="{{ route('admin.commission.index') }}" wire:navigate class="text-sm text-slate-500 hover:underline">&larr; Commission</a>

    <div class="flex items-start justify-between mt-2 mb-6">
        <div>
            <h1 class="text-xl font-semibold">{{ $company->company_name }}</h1>
            <div class="mt-1"><x-admin.status-badge :status="$company->commission_standing" /></div>
        </div>
        <div class="text-right">
            <div class="text-sm text-slate-500">Outstanding balance</div>
            <div class="text-2xl font-semibold {{ $company->outstanding_balance > 0 ? 'text-amber-700' : '' }}">
                TZS {{ number_format($company->outstanding_balance) }}
            </div>
        </div>
    </div>

    <div class="grid grid-cols-2 gap-6">
        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Ledger ({{ $ledger->count() }})</h2>
            @forelse ($ledger as $entry)
                <div class="flex items-center justify-between py-2 border-b border-slate-100 last:border-0 text-sm">
                    <div>
                        <span class="{{ $entry->entry_type === 'charge' ? 'text-red-600' : 'text-emerald-600' }} font-medium">
                            {{ $entry->entry_type === 'charge' ? '+' : '-' }} TZS {{ number_format($entry->amount) }}
                        </span>
                        <span class="text-slate-400 text-xs ml-2">{{ ucfirst($entry->entry_type) }}</span>
                    </div>
                    <span class="text-slate-400 text-xs">{{ $entry->created_at->format('Y-m-d H:i') }}</span>
                </div>
            @empty
                <p class="text-sm text-slate-400">No ledger entries yet.</p>
            @endforelse
        </div>

        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <h2 class="text-sm font-semibold text-slate-500 mb-3">Payment attempts ({{ $payments->count() }})</h2>
            @forelse ($payments as $payment)
                <div class="flex items-center justify-between py-2 border-b border-slate-100 last:border-0 text-sm">
                    <span>TZS {{ number_format($payment->amount) }} &middot; {{ $payment->mobile_money_provider }}</span>
                    <x-admin.status-badge :status="$payment->status" />
                </div>
            @empty
                <p class="text-sm text-slate-400">No payment attempts yet.</p>
            @endforelse
        </div>
    </div>
</div>
