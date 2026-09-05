<?php

namespace App\Http\Controllers;

use App\Services\Documents\DocumentStorage;
use Symfony\Component\HttpFoundation\Response;

/**
 * Serves a privately-stored document — reachable only via a signed URL
 * (the `signed` route middleware rejects a missing/invalid/expired
 * signature before this ever runs), never by guessing a path. See
 * DocumentStorage for why this exists instead of exposing files directly.
 */
class DocumentController extends Controller
{
    public function __invoke(string $key, DocumentStorage $storage): Response
    {
        abort_unless($storage->exists($key), 404);

        return $storage->response($key);
    }
}
