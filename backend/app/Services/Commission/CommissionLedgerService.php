<?php

namespace App\Services\Commission;

use App\Models\CommissionLedger;
use App\Models\Job;
use App\Models\Payment;
use App\Models\TransporterCompany;
use App\Services\Settings\PlatformSettings;
use Illuminate\Support\Facades\DB;

/**
 * The single place that ever writes a commission_ledger row or mutates
 * transporter_companies.outstanding_balance/commission_standing (Backend
 * Schema §4.7) — nothing else should touch those directly, so the two are
 * guaranteed to always agree (the ledger IS the balance's transaction
 * history, per the schema doc's own note).
 *
 * Every write locks the company row first (`lockForUpdate`, the same
 * pattern BidController::accept() uses) so a charge and a payment landing
 * at nearly the same moment can't interleave into a wrong balance or a
 * commission_standing decision based on a stale read.
 */
class CommissionLedgerService
{
    public function __construct(private readonly PlatformSettings $settings) {}

    /**
     * TRD §6: "on job completion, add agreed_price × 30% as a charge
     * entry." The rate is a configurable default (platform_settings), not
     * hardcoded, even though 30% is the only value the docs ever mention —
     * an Admin can adjust it later (Phase 9) without a deploy.
     */
    public function chargeForCompletedJob(Job $job): CommissionLedger
    {
        return DB::transaction(function () use ($job) {
            $company = TransporterCompany::whereKey($job->assigned_company_id)->lockForUpdate()->firstOrFail();

            $rate = $this->settings->getFloat('commission_rate_default', 30) / 100;
            $amount = round((float) $job->agreed_price * $rate, 2);

            $company->increment('outstanding_balance', $amount);
            $this->syncCommissionStanding($company->fresh());

            return CommissionLedger::create([
                'transporter_company_id' => $company->id,
                'entry_type' => 'charge',
                'amount' => $amount,
                'balance_after' => $company->fresh()->outstanding_balance,
                'related_job_id' => $job->id,
            ]);
        });
    }

    /**
     * Called once a mobile money payment is confirmed successful (the
     * gateway's webhook, never the initiate-charge response — see
     * MobileMoneyChargeResult's docblock). $payment.user_id is the
     * company's owner user (the payer).
     */
    public function applyPayment(Payment $payment): CommissionLedger
    {
        return DB::transaction(function () use ($payment) {
            $company = TransporterCompany::where('owner_user_id', $payment->user_id)->lockForUpdate()->firstOrFail();

            // Clamped at zero rather than tracking a credit balance — an
            // overpayment isn't a scenario the docs describe, and "the
            // company now has negative debt" would need its own handling
            // (a future charge offsetting it) that nothing here needs yet.
            $newBalance = max(0.0, (float) $company->outstanding_balance - (float) $payment->amount);
            $company->update(['outstanding_balance' => $newBalance]);
            $this->syncCommissionStanding($company);

            return CommissionLedger::create([
                'transporter_company_id' => $company->id,
                'entry_type' => 'payment',
                'amount' => $payment->amount,
                'balance_after' => $company->outstanding_balance,
                'payment_id' => $payment->id,
            ]);
        });
    }

    /**
     * Recomputed fresh from the current balance every time, in either
     * direction — never a one-way "flip to on_hold and stay there" flag —
     * so it can never drift from what the balance actually is.
     */
    private function syncCommissionStanding(TransporterCompany $company): void
    {
        $threshold = $this->settings->getFloat('commission_hold_threshold', 500000);
        $standing = (float) $company->outstanding_balance >= $threshold ? 'on_hold' : 'good_standing';

        if ($company->commission_standing !== $standing) {
            $company->update(['commission_standing' => $standing]);
        }
    }
}
