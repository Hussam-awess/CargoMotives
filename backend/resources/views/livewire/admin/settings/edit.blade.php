<div>
    <h1 class="text-xl font-semibold mb-6">Settings</h1>

    @if ($statusMessage)
        <div class="mb-4 rounded border border-emerald-300 bg-emerald-50 px-4 py-2 text-sm text-emerald-800 max-w-xl">{{ $statusMessage }}</div>
    @endif

    <div class="bg-white border border-slate-200 rounded-lg p-6 max-w-xl">
        <form wire:submit="save" class="space-y-4">
            @foreach ($labels as $key => $label)
                <div>
                    <label class="block text-sm font-medium text-slate-700 mb-1">{{ $label }}</label>
                    <input type="number" step="any" wire:model="values.{{ $key }}" class="w-full rounded border border-slate-300 text-sm px-3 py-2">
                    @error("values.{$key}") <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
                </div>
            @endforeach

            <button type="submit" class="rounded bg-slate-900 text-white text-sm font-medium px-4 py-2 hover:bg-slate-800">
                Save
            </button>
        </form>
    </div>
</div>
