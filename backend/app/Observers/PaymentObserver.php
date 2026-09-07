<?php

namespace App\Observers;

use App\Models\Payment;
use App\Observers\Concerns\ResolvesCurrentActor;
use App\Services\ActivityLog\ActivityLogger;

class PaymentObserver
{
    use ResolvesCurrentActor;

    /** @var array<string, string> */
    private const STATUS_ACTIONS = [
        'succeeded' => 'payment_succeeded',
        'failed' => 'payment_failed',
    ];

    public function __construct(private readonly ActivityLogger $activityLogger) {}

    public function updated(Payment $payment): void
    {
        if (! $payment->wasChanged('status')) {
            return;
        }

        if ($action = self::STATUS_ACTIONS[$payment->status] ?? null) {
            $this->activityLogger->record($action, $payment, $this->currentActorId(), [
                'purpose' => $payment->purpose,
                'amount' => (string) $payment->amount,
            ]);
        }
    }
}
