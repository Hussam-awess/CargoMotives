<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{{ $title ?? 'Cargo Motives Admin' }}</title>
        @vite(['resources/css/app.css'])
        @livewireStyles
    </head>
    {{--
        Plain, functional data tables — UI/UX Brief §5.9 is explicit that
        this is an internal operations tool, not a product surface: "No
        dashboard-builder aesthetics; clarity beats polish here." One
        primary color (navigation), one accent (amber, for money-related
        rows), status as a colored dot + label — same design-system rules
        as the mobile app (Brief §4), just applied to a sidebar+table shell
        instead of cards.
    --}}
    <body class="bg-slate-50 text-slate-900 antialiased">
        @auth('web')
            <div class="min-h-screen flex">
                <aside class="w-56 shrink-0 bg-slate-900 text-slate-200 flex flex-col">
                    <div class="px-4 py-4 text-base font-semibold text-white border-b border-slate-800">
                        Cargo Motives Admin
                    </div>
                    <nav class="flex-1 py-3 text-sm">
                        @php
                            $navItems = [
                                ['admin.dashboard', 'Stats'],
                                ['admin.companies.index', 'Companies'],
                                ['admin.trucks.index', 'Trucks'],
                                ['admin.search.index', 'Search'],
                                ['admin.jobs.index', 'Jobs'],
                                ['admin.disputes.index', 'Disputes'],
                                ['admin.messages.index', 'Messages'],
                                ['admin.activity-log.index', 'Activity Log'],
                                ['admin.gps.index', 'Live GPS'],
                                ['admin.settings.edit', 'Settings'],
                            ];
                        @endphp
                        @foreach ($navItems as [$routeName, $label])
                            <a
                                href="{{ route($routeName) }}"
                                wire:navigate
                                class="block px-4 py-2 {{ request()->routeIs($routeName.'*') ? 'bg-slate-800 text-white font-medium' : 'text-slate-300 hover:bg-slate-800 hover:text-white' }}"
                            >{{ $label }}</a>
                        @endforeach
                    </nav>
                    <form method="POST" action="{{ route('admin.logout') }}" class="p-4 border-t border-slate-800">
                        @csrf
                        <div class="text-xs text-slate-400 mb-2">{{ auth('web')->user()->full_name }}</div>
                        <button type="submit" class="text-sm text-slate-300 hover:text-white">Log out</button>
                    </form>
                </aside>
                {{--
                    No session('status') flash banner here — a Livewire
                    action's AJAX partial update never re-renders this
                    layout, so a flash set from inside a component would
                    silently never appear. Each component that needs a
                    confirmation message renders it inline in its own view
                    instead (see e.g. App\Livewire\Admin\Settings\Edit's
                    $statusMessage).
                --}}
                <main class="flex-1 p-6 max-w-6xl">
                    {{ $slot }}
                </main>
            </div>
        @else
            {{-- The login page: no sidebar, nothing to navigate to yet. --}}
            <div class="min-h-screen flex items-center justify-center">
                {{ $slot }}
            </div>
        @endauth
        @livewireScripts
    </body>
</html>
