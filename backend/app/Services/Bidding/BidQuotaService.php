<?php

namespace App\Services\Bidding;

use App\Models\TransporterCompany;
use App\Services\Quota\QuotaExceededException;
use App\Services\Quota\RollingQuotaService;
use App\Services\Settings\PlatformSettings;

/**
 * Applies the TRD §6 / PRD §7.4 bid-quota rule to a specific company:
 * 5 bids per rolling 24h for a standard company, 10 per rolling 15h for a
 * Featured one. The limit/window numbers come from platform_settings (Admin-
 * editable from Phase 9 on), not hardcoded here — only the *choice* between
 * the standard and Featured pair is company-specific logic.
 */
class BidQuotaService
{
    public function __construct(
        private readonly RollingQuotaService $quota,
        private readonly PlatformSettings $settings,
    ) {}

    public function remaining(TransporterCompany $company): int
    {
        [$limit, $windowSeconds] = $this->limitAndWindow($company);

        return $this->quota->remaining($this->key($company), $limit, $windowSeconds);
    }

    /**
     * @throws QuotaExceededException
     */
    public function consume(TransporterCompany $company): void
    {
        [$limit, $windowSeconds] = $this->limitAndWindow($company);

        $this->quota->consume($this->key($company), $limit, $windowSeconds);
    }

    /**
     * @return array{0: int, 1: int} [limit, windowSeconds]
     */
    private function limitAndWindow(TransporterCompany $company): array
    {
        if ($company->is_featured) {
            return [
                $this->settings->getInt('featured_bid_quota', 10),
                $this->settings->getInt('featured_bid_window_hours', 15) * 3600,
            ];
        }

        return [
            $this->settings->getInt('standard_bid_quota', 5),
            $this->settings->getInt('standard_bid_window_hours', 24) * 3600,
        ];
    }

    private function key(TransporterCompany $company): string
    {
        return "bid_quota:company:{$company->id}";
    }
}
