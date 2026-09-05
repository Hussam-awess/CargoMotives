<?php

namespace App\Services\Documents;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;

/**
 * Stores verification documents / proof-of-delivery-style uploads privately
 * and hands out only temporary signed URLs to view them — never a
 * permanent, browsable path (TRD §7: "Verification documents and
 * proof-of-delivery photos in a private bucket, signed URLs only").
 *
 * Deliberately disk-agnostic: works identically against the local disk
 * (this machine's dev setup — see README's "Docker isn't usable here" note)
 * and a real S3-compatible bucket in staging/production, since both are
 * accessed only through this one service and the signed `documents.show`
 * route below — nothing else ever reads FILESYSTEM_DISK directly for
 * uploads. Swapping disks later is a config change, not a code change.
 *
 * Failure points: a store() failure (disk full, permissions) throws
 * whatever the underlying Flysystem adapter throws — callers should let
 * that propagate as a 500 rather than silently losing the upload, since
 * verification review REQUIRES every referenced document to actually
 * exist.
 */
class DocumentStorage
{
    private const DISK = 'local';

    public function store(UploadedFile $file, string $directory): string
    {
        $filename = Str::uuid()->toString().'.'.$file->getClientOriginalExtension();

        return $file->storeAs($directory, $filename, self::DISK);
    }

    public function signedUrl(string $key, int $validForMinutes = 30): string
    {
        return URL::temporarySignedRoute(
            'documents.show',
            now()->addMinutes($validForMinutes),
            ['key' => $key],
        );
    }

    public function exists(string $key): bool
    {
        return Storage::disk(self::DISK)->exists($key);
    }

    public function response(string $key)
    {
        return Storage::disk(self::DISK)->response($key);
    }
}
