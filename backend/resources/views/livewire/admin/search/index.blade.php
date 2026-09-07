<div>
    <h1 class="text-xl font-semibold mb-6">Search</h1>

    <input
        type="text" wire:model.live.debounce.400ms="query" placeholder="Name, phone, email, registration no., or TIN"
        class="w-full max-w-lg rounded border border-slate-300 text-sm px-3 py-2 mb-6"
    >

    @if (trim($query) !== '')
        <div class="grid grid-cols-2 gap-6">
            <div>
                <h2 class="text-sm font-semibold text-slate-500 mb-2">Customers ({{ $customers->count() }})</h2>
                <div class="bg-white border border-slate-200 rounded-lg divide-y divide-slate-100">
                    @forelse ($customers as $customer)
                        <div class="px-4 py-2 text-sm">
                            <div class="font-medium">{{ $customer->full_name }}</div>
                            <div class="text-slate-500">{{ $customer->phone_number }} &middot; {{ $customer->email }}</div>
                        </div>
                    @empty
                        <div class="px-4 py-6 text-center text-slate-400 text-sm">No matching customers.</div>
                    @endforelse
                </div>
            </div>

            <div>
                <h2 class="text-sm font-semibold text-slate-500 mb-2">Companies ({{ $companies->count() }})</h2>
                <div class="bg-white border border-slate-200 rounded-lg divide-y divide-slate-100">
                    @forelse ($companies as $company)
                        <a href="{{ route('admin.companies.show', $company) }}" wire:navigate class="block px-4 py-2 text-sm hover:bg-slate-50">
                            <div class="font-medium">{{ $company->company_name }}</div>
                            <div class="text-slate-500">{{ $company->registration_number }} &middot; {{ $company->company_phone }}</div>
                        </a>
                    @empty
                        <div class="px-4 py-6 text-center text-slate-400 text-sm">No matching companies.</div>
                    @endforelse
                </div>
            </div>
        </div>
    @endif
</div>
