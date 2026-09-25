<?php

namespace App\Console\Commands;

use App\Models\TransporterCompany;
use App\Models\User;
use App\Services\Notifications\NotificationService;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

/**
 * Warns a Plus user/company before their subscription lapses — until this
 * command, `featured_until` passing silently ended benefits with no notice
 * at all. Fires at most once per subscription period, guarded by
 * `featured_expiry_reminder_sent_at` (reset on every fresh purchase by
 * FeaturedTierService::activateFromPayment()), the same idempotency idiom
 * as every other GPS/permit reminder in this app.
 */
class NotifyFeaturedExpiringSoon extends Command
{
    protected $signature = 'featured:notify-expiring-soon';

    protected $description = "Warn a Plus user/company a few days before their subscription's featured_until passes";

    public function __construct(private readonly NotificationService $notifications)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        $windowEnd = now()->addDays((int) config('featured.expiry_reminder_days_before', 3));
        $notified = 0;

        $users = User::where('is_featured', true)
            ->whereNotNull('featured_until')
            ->whereBetween('featured_until', [now(), $windowEnd])
            ->whereNull('featured_expiry_reminder_sent_at')
            ->get();

        foreach ($users as $user) {
            $user->forceFill(['featured_expiry_reminder_sent_at' => now()])->save();
            $this->notify($user, $user->featured_until);
            $notified++;
        }

        $companies = TransporterCompany::where('is_featured', true)
            ->whereNotNull('featured_until')
            ->whereBetween('featured_until', [now(), $windowEnd])
            ->whereNull('featured_expiry_reminder_sent_at')
            ->with('owner')
            ->get();

        foreach ($companies as $company) {
            $company->forceFill(['featured_expiry_reminder_sent_at' => now()])->save();
            if ($company->owner !== null) {
                $this->notify($company->owner, $company->featured_until);
                $notified++;
            }
        }

        if ($notified > 0) {
            $this->info("Warned {$notified} Plus subscriber(s) of an upcoming expiry.");
        }

        return self::SUCCESS;
    }

    private function notify(User $user, Carbon $until): void
    {
        $this->notifications->send(
            $user,
            'featured_expiring_soon',
            'Your Plus is ending soon',
            "Your Cargo Motives Plus benefits end on {$until->format('d M Y')}. Renew to keep them.",
        );
    }
}
