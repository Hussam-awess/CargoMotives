<div>
    <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-semibold">Disputes</h1>
        <select wire:model.live="status" class="rounded border border-slate-300 text-sm px-3 py-1.5">
            <option value="">All statuses</option>
            <option value="open">Open</option>
            <option value="under_review">Under review</option>
            <option value="resolved">Resolved</option>
        </select>
    </div>

    <div class="bg-white border border-slate-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
            <thead class="bg-slate-50 text-left text-slate-500 border-b border-slate-200">
                <tr>
                    <th class="px-4 py-2 font-medium">Job</th>
                    <th class="px-4 py-2 font-medium">Raised By</th>
                    <th class="px-4 py-2 font-medium">Reason</th>
                    <th class="px-4 py-2 font-medium">Status</th>
                    <th class="px-4 py-2 font-medium">Raised</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @forelse ($disputes as $dispute)
                    <tr class="hover:bg-slate-50">
                        <td class="px-4 py-2">
                            <a href="{{ route('admin.disputes.show', $dispute) }}" wire:navigate class="font-medium text-slate-900 hover:underline">
                                #{{ $dispute->job_id }}
                            </a>
                        </td>
                        <td class="px-4 py-2 text-slate-600">{{ $dispute->raisedBy?->full_name }}</td>
                        <td class="px-4 py-2 text-slate-600">{{ \Illuminate\Support\Str::limit($dispute->reason, 50) }}</td>
                        <td class="px-4 py-2"><x-admin.status-badge :status="$dispute->status" /></td>
                        <td class="px-4 py-2 text-slate-500">{{ $dispute->created_at->format('Y-m-d') }}</td>
                    </tr>
                @empty
                    <tr><td colspan="5" class="px-4 py-6 text-center text-slate-400">No disputes match this filter.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="mt-4">{{ $disputes->links() }}</div>
</div>
