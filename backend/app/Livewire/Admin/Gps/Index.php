<?php

namespace App\Livewire\Admin\Gps;

use App\Models\Truck;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * "Basic GPS/live-ops view — a simple view of which trucks are currently
 * live" (PRD §10 item 10). Reads the already-persisted
 * trucks.last_known_* columns (populated by the Phase 6 poll pipeline),
 * the same reuse pattern as TruckController::map() (the Featured fleet
 * map) — just company-wide instead of scoped to one company, and with no
 * is_featured gate. No real map rendered, for the same already-
 * established reason as everywhere else in this app: no Google Maps API
 * key is provisioned — a live position/heading/last-updated table still
 * exercises the real data.
 */
#[Layout('layouts.admin')]
class Index extends Component
{
    public function render()
    {
        return view('livewire.admin.gps.index', [
            'connectedTrucks' => Truck::where('gps_status', 'connected')->with('company')->orderByDesc('last_known_at')->get(),
            'signalLostTrucks' => Truck::where('gps_status', 'signal_lost')->with('company')->orderByDesc('last_known_at')->get(),
        ]);
    }
}
