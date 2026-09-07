<div>
    <h1 class="text-xl font-semibold mb-6">Live GPS</h1>

    <div class="bg-white border border-slate-200 rounded-lg overflow-hidden mb-6">
        <div class="px-4 py-2 bg-slate-50 border-b border-slate-200 text-sm font-medium text-slate-500">
            Connected ({{ $connectedTrucks->count() }})
        </div>
        <table class="w-full text-sm">
            <thead class="text-left text-slate-500 border-b border-slate-200">
                <tr>
                    <th class="px-4 py-2 font-medium">Truck</th>
                    <th class="px-4 py-2 font-medium">Company</th>
                    <th class="px-4 py-2 font-medium">Position</th>
                    <th class="px-4 py-2 font-medium">Heading</th>
                    <th class="px-4 py-2 font-medium">Last updated</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @forelse ($connectedTrucks as $truck)
                    <tr>
                        <td class="px-4 py-2 font-medium">{{ $truck->registration_number }}</td>
                        <td class="px-4 py-2 text-slate-600">{{ $truck->company?->company_name }}</td>
                        <td class="px-4 py-2 text-slate-600">
                            @if ($truck->last_known_lat !== null)
                                {{ number_format($truck->last_known_lat, 4) }}, {{ number_format($truck->last_known_lng, 4) }}
                            @else
                                —
                            @endif
                        </td>
                        <td class="px-4 py-2 text-slate-600">{{ $truck->last_known_heading !== null ? $truck->last_known_heading.'°' : '—' }}</td>
                        <td class="px-4 py-2 text-slate-500">{{ $truck->last_known_at?->diffForHumans() ?? '—' }}</td>
                    </tr>
                @empty
                    <tr><td colspan="5" class="px-4 py-6 text-center text-slate-400">No trucks are currently GPS-connected.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="bg-white border border-amber-200 rounded-lg overflow-hidden">
        <div class="px-4 py-2 bg-amber-50 border-b border-amber-200 text-sm font-medium text-amber-800">
            Signal lost ({{ $signalLostTrucks->count() }})
        </div>
        <table class="w-full text-sm">
            <tbody class="divide-y divide-slate-100">
                @forelse ($signalLostTrucks as $truck)
                    <tr>
                        <td class="px-4 py-2 font-medium">{{ $truck->registration_number }}</td>
                        <td class="px-4 py-2 text-slate-600">{{ $truck->company?->company_name }}</td>
                        <td class="px-4 py-2 text-slate-500">Last seen {{ $truck->last_known_at?->diffForHumans() ?? 'never' }}</td>
                    </tr>
                @empty
                    <tr><td class="px-4 py-6 text-center text-slate-400">No trucks currently have a lost signal.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>
