<?php

namespace App\Services\Bidding;

use App\Models\TransporterCompany;
use App\Services\Quota\QuotaExceededException;
use App\Services\Quota\RollingQuotaService;
use App\Services\Settings\PlatformSettings;

/**
 * Applies the bid-quota rule to a specific company: 10 bids per rolling
 * 24h for a standard company, no limit at all for a Cargo Motives Plus
 * one. The standard limit/window come from platform_settings (Admin-
 * editable), not hardcoded here.
 *
 * A Plus company never touches RollingQuotaService at all — there's no
 * per-tier limit number to look up, just an outright bypass — so
 * `remaining()` returns UNLIMITED (-1) for one, a value no real rolling
 * count can ever produce, rather than a very large but technically finite
 * stand-in number.
 */
class BidQuotaService
{
    /**
     * Never a real "remaining count" — the sentinel a Plus company's
     * `remaining()` returns, since there's no cap to count down from.
     */
    public const UNLIMITED = -1;

    public function __construct(
        private readonly RollingQuotaService $quota,
        private readonly PlatformSettings $settings,
    ) {}

    public function remaining(TransporterCompany $company): int
    {
        if ($company->is_featured) {
            return self::UNLIMITED;
        }

        return $this->quota->remaining($this->key($company), $this->standardLimit(), $this->standardWindowSeconds());
    }

    /**
     * @throws QuotaExceededException
     */
    public function consume(TransporterCompany $company): void
    {
        if ($company->is_featured) {
            return;
        }

        $this->quota->consume($this->key($company), $this->standardLimit(), $this->standardWindowSeconds());
    }

    private function standardLimit(): int
    {
        return $this->settings->getInt('standard_bid_quota', 10);
    }

    private function standardWindowSeconds(): int
    {
        return $this->settings->getInt('standard_bid_window_hours', 24) * 3600;
    }

    private function key(TransporterCompany $company): string
    {
        return "bid_quota:company:{$company->id}";
    }
}
