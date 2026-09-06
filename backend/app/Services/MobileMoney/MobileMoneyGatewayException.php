<?php

namespace App\Services\MobileMoney;

use RuntimeException;

/**
 * A gateway call failed outright (unreachable, misconfigured credentials,
 * unreadable response) — distinct from PaymentController choosing to
 * store a `failed` Payment row for a charge the gateway *did* respond to
 * cleanly but rejected. Callers catch this and record the attempt as
 * failed rather than letting it propagate as a 500 — a payment failing to
 * initiate must never block the job it's for (TRD §5.3).
 */
class MobileMoneyGatewayException extends RuntimeException {}
