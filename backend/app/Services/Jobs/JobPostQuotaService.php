<?php

namespace App\Services\Jobs;

use App\Models\User;
use App\Services\Quota\QuotaExceededException;
use App\Services\Quota\RollingQuotaService;
use App\Services\Settings\PlatformSettings;

/**
 * The customer-side counterpart to BidQuotaService: 10 job posts per
 * rolling 24h for a standard customer, no limit at all for a Cargo
 * Motives Plus one. A customer's daily quota window is treated as a
 * rolling 24h window rather than a calendar-day reset, for consistency
 * with how every other quota in this app works (and to avoid a separate
 * calendar-boundary implementation for no documented reason).
 *
 * A Plus customer never touches RollingQuotaService at all — there's no
 * per-tier limit number to look up, just an outright bypass — so
 * `remaining()` returns UNLIMITED (-1) for one, a value no real rolling
 * count can ever produce, rather than a very large but technically finite
 * stand-in number.
 */
class JobPostQuotaService
{
    /**
     * Never a real "remaining count" — the sentinel a Plus customer's
     * `remaining()` returns, since there's no cap to count down from.
     */
    public const UNLIMITED = -1;

    public function __construct(
        private readonly RollingQuotaService $quota,
        private readonly PlatformSettings $settings,
    ) {}

    public function remaining(User $customer): int
    {
        if ($customer->is_featured) {
            return self::UNLIMITED;
        }

        return $this->quota->remaining($this->key($customer), $this->standardLimit(), 24 * 3600);
    }

    /**
     * @throws QuotaExceededException
     */
    public function consume(User $customer): void
    {
        if ($customer->is_featured) {
            return;
        }

        $this->quota->consume($this->key($customer), $this->standardLimit(), 24 * 3600);
    }

    private function standardLimit(): int
    {
        return $this->settings->getInt('standard_customer_post_quota', 10);
    }

    private function key(User $customer): string
    {
        return "job_post_quota:customer:{$customer->id}";
    }
}
