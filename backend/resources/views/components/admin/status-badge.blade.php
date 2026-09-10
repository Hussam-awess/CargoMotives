@props(['status'])
@php
    // UI/UX Brief §4: "Status is communicated with small colored dots + a
    // text label... not a proliferation of themed accents per feature."
    // One shared mapping for every admin list/detail screen, rather than
    // each screen inventing its own color choice per status string.
    $colors = match ($status) {
        'approved', 'connected', 'completed', 'resolved', 'succeeded', 'active' => 'bg-emerald-500',
        'pending', 'idle', 'not_connected', 'initiated', 'pending_confirmation' => 'bg-slate-400',
        'flagged_duplicate', 'under_review', 'open', 'signal_lost' => 'bg-amber-500',
        'rejected', 'cancelled', 'failed', 'withdrawn' => 'bg-red-500',
        default => 'bg-slate-300',
    };
@endphp
<span class="inline-flex items-center gap-1.5 text-sm">
    <span class="w-2 h-2 rounded-full {{ $colors }}"></span>
    {{ ucwords(str_replace('_', ' ', $status)) }}
</span>
