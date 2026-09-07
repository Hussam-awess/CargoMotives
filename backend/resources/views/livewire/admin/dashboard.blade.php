<div>
    <h1 class="text-xl font-semibold mb-6">Stats</h1>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <div class="text-sm text-slate-500">Jobs posted</div>
            <div class="text-2xl font-semibold mt-1">{{ number_format($jobsPosted) }}</div>
        </div>
        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <div class="text-sm text-slate-500">Jobs completed</div>
            <div class="text-2xl font-semibold mt-1">{{ number_format($jobsCompleted) }}</div>
        </div>
        <div class="bg-white border border-slate-200 rounded-lg p-4">
            <div class="text-sm text-slate-500">Active companies</div>
            <div class="text-2xl font-semibold mt-1">{{ number_format($activeCompanies) }}</div>
        </div>
        <div class="bg-white border border-amber-200 bg-amber-50 rounded-lg p-4">
            <div class="text-sm text-amber-700">Commission collected</div>
            <div class="text-2xl font-semibold mt-1 text-amber-900">TZS {{ number_format($commissionCollected, 0) }}</div>
        </div>
    </div>
</div>
