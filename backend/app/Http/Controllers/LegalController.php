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
     * document changes daily. Update the relevant constant only when that
     * document's own wording changes — kept separate per document since
     * Terms and Privacy are edited independently (e.g. Phase 10.13 touched
     * only Terms, this pass touched only Privacy).
     */
    private const PRIVACY_LAST_UPDATED = '2026-09-25';

    private const TERMS_LAST_UPDATED = '2026-09-25';

    public function privacy(): View
    {
        return view('legal.privacy', ['updatedAt' => self::formattedDate(self::PRIVACY_LAST_UPDATED)]);
    }

    public function terms(): View
    {
        return view('legal.terms', ['updatedAt' => self::formattedDate(self::TERMS_LAST_UPDATED)]);
    }

    private static function formattedDate(string $date): string
    {
        return Carbon::parse($date)->format('F j, Y');
    }
}
