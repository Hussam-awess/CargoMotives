<?php

namespace App\Http\Controllers;

use Illuminate\Support\Carbon;
use Illuminate\View\View;

/**
 * Public legal pages (Phase 10 launch prep) — both the Play Store and App
 * Store require a hosted privacy-policy URL at submission; a Terms of
 * Service page isn't strictly required by either store but is standard
 * practice and directly referenced by the Terms themselves (account
 * verification, commission, disputes). Plain Blade, no auth, no build
 * step — same reasoning as the Driver Link pages.
 */
class LegalController extends Controller
{
    /**
     * A fixed date each document was actually last written, not now() —
     * showing "today" on every single request would falsely imply the
     * document changes daily. Update this constant only when the actual
     * wording changes.
     */
    private const LAST_UPDATED = '2026-09-07';

    public function privacy(): View
    {
        return view('legal.privacy', ['updatedAt' => self::formattedDate()]);
    }

    public function terms(): View
    {
        return view('legal.terms', ['updatedAt' => self::formattedDate()]);
    }

    private static function formattedDate(): string
    {
        return Carbon::parse(self::LAST_UPDATED)->format('F j, Y');
    }
}
