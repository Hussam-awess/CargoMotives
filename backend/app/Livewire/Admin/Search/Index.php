<?php

namespace App\Livewire\Admin\Search;

use App\Models\TransporterCompany;
use App\Models\User;
use Illuminate\Support\Collection;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Url;
use Livewire\Component;

/**
 * "Find any customer or company quickly" (PRD §10 item 3). No filters are
 * itemized in the docs beyond that one sentence — a single search box
 * over name/phone/email (customers) and name/registration/TIN
 * (companies) is the reasonable minimum, per the UI/UX Brief's "plain,
 * functional" guidance rather than a faceted-search UI nothing asked for.
 */
#[Layout('layouts.admin')]
class Index extends Component
{
    #[Url]
    public string $query = '';

    public function render()
    {
        $term = trim($this->query);

        return view('livewire.admin.search.index', [
            'customers' => $term === '' ? collect() : $this->searchCustomers($term),
            'companies' => $term === '' ? collect() : $this->searchCompanies($term),
        ]);
    }

    private function searchCustomers(string $term): Collection
    {
        return User::where('account_type', 'customer')
            ->where(function ($q) use ($term) {
                $q->where('full_name', 'like', "%{$term}%")
                    ->orWhere('phone_number', 'like', "%{$term}%")
                    ->orWhere('email', 'like', "%{$term}%");
            })
            ->limit(20)
            ->get();
    }

    private function searchCompanies(string $term): Collection
    {
        return TransporterCompany::where(function ($q) use ($term) {
            $q->where('company_name', 'like', "%{$term}%")
                ->orWhere('registration_number', 'like', "%{$term}%")
                ->orWhere('tin', 'like', "%{$term}%")
                ->orWhere('company_phone', 'like', "%{$term}%");
        })
            ->limit(20)
            ->get();
    }
}
