<div>
    <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-semibold">Activity Log</h1>
        <select wire:model.live="action" class="rounded border border-slate-300 text-sm px-3 py-1.5">
            <option value="">All actions</option>
            @foreach ($actions as $a)
                <option value="{{ $a }}">{{ ucwords(str_replace('_', ' ', $a)) }}</option>
            @endforeach
        </select>
    </div>

    <div class="bg-white border border-slate-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
            <thead class="bg-slate-50 text-left text-slate-500 border-b border-slate-200">
                <tr>
                    <th class="px-4 py-2 font-medium">When</th>
                    <th class="px-4 py-2 font-medium">Action</th>
                    <th class="px-4 py-2 font-medium">Subject</th>
                    <th class="px-4 py-2 font-medium">Actor</th>
                    <th class="px-4 py-2 font-medium">Details</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @forelse ($entries as $entry)
                    <tr class="hover:bg-slate-50">
                        <td class="px-4 py-2 text-slate-500 whitespace-nowrap">{{ $entry->created_at->format('Y-m-d H:i:s') }}</td>
                        <td class="px-4 py-2 font-medium">{{ ucwords(str_replace('_', ' ', $entry->action)) }}</td>
                        <td class="px-4 py-2 text-slate-600">{{ class_basename($entry->subject_type) }} #{{ $entry->subject_id }}</td>
                        <td class="px-4 py-2 text-slate-600">{{ $entry->actor?->full_name ?? 'System' }}</td>
                        <td class="px-4 py-2 text-slate-500">{{ $entry->metadata ? json_encode($entry->metadata) : '—' }}</td>
                    </tr>
                @empty
                    <tr><td colspan="5" class="px-4 py-6 text-center text-slate-400">No activity matches this filter.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="mt-4">{{ $entries->links() }}</div>
</div>
