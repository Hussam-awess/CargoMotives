<div>
    <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-semibold">Trucks</h1>
        <select wire:model.live="status" class="rounded border border-slate-300 text-sm px-3 py-1.5">
            <option value="">All statuses</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
        </select>
    </div>

    <div class="bg-white border border-slate-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
            <thead class="bg-slate-50 text-left text-slate-500 border-b border-slate-200">
                <tr>
                    <th class="px-4 py-2 font-medium">Registration No.</th>
                    <th class="px-4 py-2 font-medium">Company</th>
                    <th class="px-4 py-2 font-medium">Make/Model</th>
                    <th class="px-4 py-2 font-medium">Status</th>
                    <th class="px-4 py-2 font-medium">GPS</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @forelse ($trucks as $truck)
                    <tr class="hover:bg-slate-50">
                        <td class="px-4 py-2">
                            <a href="{{ route('admin.trucks.show', $truck) }}" wire:navigate class="font-medium text-slate-900 hover:underline">
                                {{ $truck->registration_number }}
                            </a>
                        </td>
                        <td class="px-4 py-2 text-slate-600">{{ $truck->company?->company_name }}</td>
                        <td class="px-4 py-2 text-slate-600">{{ $truck->make_model }}</td>
                        <td class="px-4 py-2"><x-admin.status-badge :status="$truck->verification_status" /></td>
                        <td class="px-4 py-2"><x-admin.status-badge :status="$truck->gps_status" /></td>
                    </tr>
                @empty
                    <tr><td colspan="5" class="px-4 py-6 text-center text-slate-400">No trucks match this filter.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="mt-4">{{ $trucks->links() }}</div>
</div>
