<div>
    <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-semibold">Commission &amp; Payment Status</h1>
        <select wire:model.live="standing" class="rounded border border-slate-300 text-sm px-3 py-1.5">
            <option value="">All companies</option>
            <option value="good_standing">Good standing</option>
            <option value="on_hold">On hold</option>
        </select>
    </div>

    <div class="bg-white border border-slate-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
            <thead class="bg-slate-50 text-left text-slate-500 border-b border-slate-200">
                <tr>
                    <th class="px-4 py-2 font-medium">Company</th>
                    <th class="px-4 py-2 font-medium">Outstanding Balance</th>
                    <th class="px-4 py-2 font-medium">Standing</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @forelse ($companies as $company)
                    <tr class="hover:bg-slate-50">
                        <td class="px-4 py-2">
                            <a href="{{ route('admin.commission.show', $company) }}" wire:navigate class="font-medium text-slate-900 hover:underline">
                                {{ $company->company_name }}
                            </a>
                        </td>
                        <td class="px-4 py-2 {{ $company->outstanding_balance > 0 ? 'text-amber-700 font-medium' : 'text-slate-600' }}">
                            TZS {{ number_format($company->outstanding_balance) }}
                        </td>
                        <td class="px-4 py-2"><x-admin.status-badge :status="$company->commission_standing" /></td>
                    </tr>
                @empty
                    <tr><td colspan="3" class="px-4 py-6 text-center text-slate-400">No companies match this filter.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="mt-4">{{ $companies->links() }}</div>
</div>
