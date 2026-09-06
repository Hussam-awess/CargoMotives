<?php

namespace App\Services\Jobs;

use App\Models\User;
use App\Services\Quota\QuotaExceededException;
use App\Services\Quota\RollingQuotaService;
use App\Services\Settings\PlatformSettings;

/**
 * The customer-side counterpart to BidQuotaService (PRD §7.8): 5 job posts
 * per rolling 24h for a standard customer, 10 for a Featured one. Same
 * algorithm, same settings-driven limits — a customer's daily quota window
 * is treated as a rolling 24h window rather than a calendar-day reset, for
 * consistency with how every other quota in this app works (and to avoid
 * a separate calendar-boundary implementation for no documented reason).
 */
class JobPostQuotaService
{
    public function __construct(
        private readonly RollingQuotaService $quota,
        private readonly PlatformSettings $settings,
    ) {}

    public function remaining(User $customer): int
    {
        [$limit, $windowSeconds] = $this->limitAndWindow($customer);

        return $this->quota->remaining($this->key($customer), $limit, $windowSeconds);
    }

    /**
     * @throws QuotaExceededException
     */
    public function consume(User $customer): void
    {
        [$limit, $windowSeconds] = $this->limitAndWindow($customer);

        $this->quota->consume($this->key($customer), $limit, $windowSeconds);
    }

    /**
     * @return array{0: int, 1: int} [limit, windowSeconds]
     */
    private function limitAndWindow(User $customer): array
    {
        $limit = $customer->is_featured
            ? $this->settings->getInt('featured_customer_post_quota', 10)
            : $this->settings->getInt('standard_customer_post_quota', 5);

        return [$limit, 24 * 3600];
    }

    private function key(User $customer): string
    {
        return "job_post_quota:customer:{$customer->id}";
    }
}
