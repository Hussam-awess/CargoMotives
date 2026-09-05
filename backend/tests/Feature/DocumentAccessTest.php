<?php

namespace Tests\Feature;

use App\Services\Documents\DocumentStorage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * TRD §7: verification documents live in a private bucket, signed URLs
 * only. Covers both halves of that: a valid signed URL works, and the raw
 * path does not.
 */
class DocumentAccessTest extends TestCase
{
    public function test_a_valid_signed_url_serves_the_file(): void
    {
        Storage::fake('local');
        $storage = new DocumentStorage;
        $key = $storage->store(UploadedFile::fake()->create('license.pdf', 10, 'application/pdf'), 'companies/documents');

        $this->get($storage->signedUrl($key))->assertOk();
    }

    public function test_the_raw_unsigned_path_is_rejected(): void
    {
        Storage::fake('local');
        $storage = new DocumentStorage;
        $key = $storage->store(UploadedFile::fake()->create('license.pdf', 10, 'application/pdf'), 'companies/documents');

        $this->get("/api/documents/{$key}")->assertForbidden();
    }

    public function test_a_signed_url_for_a_missing_file_404s(): void
    {
        Storage::fake('local');
        $storage = new DocumentStorage;

        $this->get($storage->signedUrl('companies/documents/does-not-exist.pdf'))->assertNotFound();
    }
}
