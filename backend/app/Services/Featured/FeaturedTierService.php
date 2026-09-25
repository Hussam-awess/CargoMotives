<?php

namespace App\Services\Featured;

use App\Models\Payment;
use App\Models\TransporterCompany;
use App\Models\User;
use App\Services\Settings\PlatformSettings;
use InvalidArgumentException;

/**
 * The write side of Featured purchases (AppFlow §2.7/§3.6: "pay via
 * mobile money → unlocks immediately"). Called only once a payment is
 * confirmed successful (SelcomWebhookController), never from the
 * initiate-purchase response — "confirmation is asynchronous, never
 * assumed."
 *
 * Every other Featured-gated behavior already reads `is_featured` off
 * TransporterCompany/User directly (BidQuotaService, JobPostQuotaService,
 * bids' `is_priority` flag — all built in Phase 4, before this service
 * ever existed to flip the flag) — this is the one place that ever sets
 * it, so nothing else needs to change to "notice" a purchase.
 */
class FeaturedTierService
{
    public function __construct(private readonly PlatformSettings $settings) {}

    public function activateFromPayment(Payment $payment): void
    {
        $until = now()->addDays($this->settings->getInt('featured_duration_days', 30));

        $model = match ($payment->purpose) {
            'featured_company' => TransporterCompany::where('owner_user_id', $payment->user_id)->firstOrFail(),
            'featured_customer' => User::whereKey($payment->user_id)->firstOrFail(),
            default => throw new InvalidArgumentException("Payment #{$payment->id} has no Featured activation for purpose '{$payment->purpose}'."),
        };

        // featured_expiry_reminder_sent_at is system-only (never in either
        // model's #[Fillable]), so it needs forceFill — reset here on every
        // (re-)purchase so a renewal gets its own fresh expiry-warning
        // cycle rather than staying permanently "already reminded" from a
        // previous subscription period.
        $model->update(['is_featured' => true, 'featured_until' => $until]);
        $model->forceFill(['featured_expiry_reminder_sent_at' => null])->save();
    }
}
