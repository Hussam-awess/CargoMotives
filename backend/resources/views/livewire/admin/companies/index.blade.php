<div>
    <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-semibold">Companies</h1>
        <select wire:model.live="status" class="rounded border border-slate-300 text-sm px-3 py-1.5">
            <option value="">All statuses</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
            <option value="flagged_duplicate">Flagged duplicate</option>
        </select>
    </div>

    <div class="bg-white border border-slate-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
            <thead class="bg-slate-50 text-left text-slate-500 border-b border-slate-200">
                <tr>
                    <th class="px-4 py-2 font-medium">Company</th>
                    <th class="px-4 py-2 font-medium">Registration No.</th>
                    <th class="px-4 py-2 font-medium">TIN</th>
                    <th class="px-4 py-2 font-medium">Status</th>
                    <th class="px-4 py-2 font-medium">Applied</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @forelse ($companies as $company)
                    <tr class="hover:bg-slate-50 cursor-pointer" onclick="window.location='{{ route('admin.companies.show', $company) }}'">
                        <td class="px-4 py-2">
                            <a href="{{ route('admin.companies.show', $company) }}" wire:navigate class="font-medium text-slate-900 hover:underline">
                                {{ $company->company_name }}
                            </a>
                        </td>
                        <td class="px-4 py-2 text-slate-600">{{ $company->registration_number }}</td>
                        <td class="px-4 py-2 text-slate-600">{{ $company->tin }}</td>
                        <td class="px-4 py-2"><x-admin.status-badge :status="$company->verification_status" /></td>
                        <td class="px-4 py-2 text-slate-500">{{ $company->created_at->format('Y-m-d') }}</td>
                    </tr>
                @empty
                    <tr><td colspan="5" class="px-4 py-6 text-center text-slate-400">No companies match this filter.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="mt-4">{{ $companies->links() }}</div>
</div>
