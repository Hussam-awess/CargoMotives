<div>
    <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-semibold">Jobs</h1>
        <select wire:model.live="status" class="rounded border border-slate-300 text-sm px-3 py-1.5">
            <option value="">All statuses</option>
            @foreach ($statuses as $s)
                <option value="{{ $s }}">{{ ucwords(str_replace('_', ' ', $s)) }}</option>
            @endforeach
        </select>
    </div>

    <div class="bg-white border border-slate-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
            <thead class="bg-slate-50 text-left text-slate-500 border-b border-slate-200">
                <tr>
                    <th class="px-4 py-2 font-medium">Job</th>
                    <th class="px-4 py-2 font-medium">Customer</th>
                    <th class="px-4 py-2 font-medium">Assigned Company</th>
                    <th class="px-4 py-2 font-medium">Status</th>
                    <th class="px-4 py-2 font-medium">Agreed Price</th>
                    <th class="px-4 py-2 font-medium">Posted</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @forelse ($jobs as $job)
                    <tr class="hover:bg-slate-50">
                        <td class="px-4 py-2">
                            <a href="{{ route('admin.jobs.show', $job) }}" wire:navigate class="font-medium text-slate-900 hover:underline">
                                #{{ $job->id }} &middot; {{ \Illuminate\Support\Str::limit($job->pickup_address, 20) }} &rarr; {{ \Illuminate\Support\Str::limit($job->dropoff_address, 20) }}
                            </a>
                        </td>
                        <td class="px-4 py-2 text-slate-600">{{ $job->customer?->full_name }}</td>
                        <td class="px-4 py-2 text-slate-600">{{ $job->assignedCompany?->company_name ?? '—' }}</td>
                        <td class="px-4 py-2"><x-admin.status-badge :status="$job->status" /></td>
                        <td class="px-4 py-2 text-slate-600">{{ $job->agreed_price ? 'TZS '.number_format($job->agreed_price) : '—' }}</td>
                        <td class="px-4 py-2 text-slate-500">{{ $job->created_at->format('Y-m-d') }}</td>
                    </tr>
                @empty
                    <tr><td colspan="6" class="px-4 py-6 text-center text-slate-400">No jobs match this filter.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="mt-4">{{ $jobs->links() }}</div>
</div>
