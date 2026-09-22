<?php

namespace App\Livewire\Admin\Settings;

use App\Models\PlatformSetting;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Livewire\Attributes\Layout;
use Livewire\Component;

/**
 * "No separate settings/configuration UI is required beyond a handful of
 * values... editable via a single basic form — not a full settings
 * module" (TRD §8). Exactly the keys PlatformSettingsSeeder already
 * seeds — this form doesn't let Admin invent arbitrary new keys, since
 * every key it edits is one specific call sites across Phases 4/7/8
 * actually read by name (App\Services\Settings\PlatformSettings); a
 * free-form key/value editor would let Admin create settings nothing
 * reads, or silently mistype one a call site depends on.
 */
#[Layout('layouts.admin')]
class Edit extends Component
{
    /** @var array<string, string> */
    public array $values = [];

    /**
     * Rendered inline by this component's own view — a Livewire action is
     * an AJAX partial update that never re-renders the surrounding Blade
     * layout, so session()->flash() read there would silently never
     * appear (caught live: after Save, the form looks identical whether
     * it succeeded or not, with no automated test able to catch it since
     * Livewire::test() only inspects the component's own rendered HTML).
     */
    public ?string $statusMessage = null;

    /**
     * Labels only — no defaults here. If a key is somehow missing from
     * the database (should never happen once PlatformSettingsSeeder has
     * run), this form shows a blank field rather than silently
     * fabricating a value someone might mistake for the real one.
     *
     * @var array<string, string>
     */
    // Cargo Motives Plus has no bid/post quota at all (BidQuotaService/
    // JobPostQuotaService bypass the limit outright for a Plus company or
    // customer) — there's nothing left here for an admin to tune on that
    // side, only the standard tier's numbers.
    private const LABELS = [
        'standard_bid_quota' => 'Standard bid quota',
        'standard_bid_window_hours' => 'Standard bid window (hours)',
        'standard_customer_post_quota' => 'Standard customer post quota',
        'company_featured_price' => 'Company Featured price (TZS)',
        'customer_featured_price' => 'Customer Featured price (TZS)',
        'featured_duration_days' => 'Featured duration (days)',
    ];

    public function mount(): void
    {
        $existing = PlatformSetting::whereIn('key', array_keys(self::LABELS))->pluck('value', 'key');

        foreach (self::LABELS as $key => $label) {
            $this->values[$key] = (string) ($existing[$key] ?? '');
        }
    }

    public function save(): void
    {
        $this->validate(
            collect(self::LABELS)->keys()->mapWithKeys(fn ($key) => ["values.{$key}" => ['required', 'numeric']])->all(),
        );

        foreach ($this->values as $key => $value) {
            PlatformSetting::updateOrCreate(
                ['key' => $key],
                ['value' => (string) $value, 'updated_by_admin_id' => Auth::guard('web')->id()],
            );
            // PlatformSettings caches reads for 60s (see that class's
            // docblock) — busting it here means an edit takes effect on
            // the very next request, not up to a minute later.
            Cache::forget("platform_setting:{$key}");
        }

        $this->statusMessage = 'Settings saved.';
    }

    public function render()
    {
        return view('livewire.admin.settings.edit', ['labels' => self::LABELS]);
    }
}
