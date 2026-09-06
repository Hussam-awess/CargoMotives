<?php

namespace App\Services\Gps;

use RuntimeException;

/**
 * A GPS provider call failed — a bad/expired access token, the provider's
 * API being unreachable, or an unexpected response shape. Callers decide
 * what "failed" means for them: the Connect flow surfaces it as a
 * validation error; the poll job catches it per-connection (TRD §5.3 —
 * one company's bad token must never stop other companies' trucks from
 * updating) and marks that connection 'error' rather than letting the
 * whole cycle crash.
 */
class GpsProviderException extends RuntimeException {}
