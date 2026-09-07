<div class="w-full max-w-sm bg-white border border-slate-200 rounded-lg p-6 shadow-sm">
    <h1 class="text-lg font-semibold mb-1">Cargo Motives Admin</h1>
    <p class="text-sm text-slate-500 mb-6">Sign in to manage the marketplace.</p>

    <form wire:submit="login" class="space-y-4">
        <div>
            <label for="email" class="block text-sm font-medium text-slate-700 mb-1">Email</label>
            <input
                type="email" id="email" wire:model="email" autofocus autocomplete="username"
                class="w-full rounded border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-slate-500"
            >
            @error('email') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
        </div>

        <div>
            <label for="password" class="block text-sm font-medium text-slate-700 mb-1">Password</label>
            <input
                type="password" id="password" wire:model="password" autocomplete="current-password"
                class="w-full rounded border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-slate-500"
            >
            @error('password') <p class="mt-1 text-sm text-red-600">{{ $message }}</p> @enderror
        </div>

        <label class="flex items-center gap-2 text-sm text-slate-600">
            <input type="checkbox" wire:model="remember" class="rounded border-slate-300">
            Remember me
        </label>

        <button
            type="submit"
            class="w-full rounded bg-slate-900 text-white text-sm font-medium py-2 hover:bg-slate-800"
            wire:loading.attr="disabled" wire:target="login"
        >
            <span wire:loading.remove wire:target="login">Sign in</span>
            <span wire:loading wire:target="login">Signing in…</span>
        </button>
    </form>
</div>
