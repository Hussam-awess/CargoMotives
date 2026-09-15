import 'package:flutter/material.dart';

/// Cargo Motives design tokens.
///
/// Design-import restyle: navy + steel-blue palette and Barlow/Barlow
/// Condensed typography, sourced from a Claude Design mockup
/// ("Cargo Motives App.dc.html", the "Industry" visual system) — applied
/// so far to the onboarding/auth flow; other screens still use these same
/// tokens (a global theme change reaches every screen automatically) but
/// haven't had their bespoke layouts restyled yet.
///
/// Status-dot colors and the money-action accent are deliberately
/// unchanged — the mockup doesn't redesign those in this pass, and this
/// app's own UI/UX brief is explicit that a status color always pairs with
/// a text label, never color alone.
///
/// **Dark mode (real, not a preview)**: most tokens below are getters that
/// branch on [AppColors.brightness] rather than plain `static const`
/// values, so every widget reading e.g. `AppColors.surface` gets the right
/// color for whichever theme is active — the same call site, no `context`
/// needed. [CargoMotivesApp] sets [AppColors.brightness] once per rebuild,
/// before any descendant screen builds (see app.dart), driven by
/// [ThemeController]. Action/brand colors (`ctaBlue`, `accent`, the status
/// colors, `brandChip`) stay constant across themes on purpose — inverting
/// a brand or semantic color on every theme flip reads as broken, not
/// polished; only the neutrals (backgrounds/surfaces/borders/text) and
/// `primary` (used as headline-weight ink text) actually invert.
abstract final class AppColors {
  static Brightness _brightness = Brightness.light;

  /// Set once per app rebuild by [CargoMotivesApp], before any descendant
  /// widget's `build()` runs — see that class's docblock. Not itself
  /// reactive; every `AppColors.*` getter below just reads this synchronously.
  static void setBrightness(Brightness brightness) => _brightness = brightness;

  static Brightness get brightness => _brightness;

  static bool get _isDark => _brightness == Brightness.dark;

  /// Navy — brand ink, used as headline-weight text color throughout the
  /// app (both via `Theme.of(context).textTheme` and many bespoke
  /// `TextStyle`s). Inverts to a near-white ink in dark mode so headline
  /// text stays legible against a dark background.
  static Color get primary => _isDark ? const Color(0xFFEAF0F4) : const Color(0xFF1D2D3D);
  static Color get primaryDark => primary;

  /// The same brand navy as light-mode `primary`, but held constant across
  /// both themes — for the handful of spots (logo mark, icon-badge chips)
  /// that are a fixed dark-navy fill with a white icon on top regardless of
  /// app theme, not "ink text" that should invert. Split out from `primary`
  /// specifically so dark mode doesn't turn those chips white-on-white.
  static const brandChip = Color(0xFF1D2D3D);

  /// The Identity Sheet v2 logo palette — the exact hex values from the
  /// brand mark (assets/brand/logo_mark.svg), used only where that mark
  /// itself appears (Splash, Welcome) and its immediate surroundings.
  /// Deliberately separate from `primary`/`ctaBlue` above: this is the logo's
  /// own fixed identity, not the app's general UI action/ink palette, and
  /// isn't meant to replace it everywhere.
  static const brandLogoNavy = Color(0xFF16294B);
  static const brandLogoDeepNavy = Color(0xFF0E1B33);
  static const brandLogoOrange = Color(0xFFE2621B);
  static const brandLogoBone = Color(0xFFF4EFE6);

  /// Steel-blue — the one interactive/CTA color: primary buttons, links,
  /// focus rings. Distinct from `primary` (navy is ink, not an action
  /// color) and from `accent` (amber is money, not general interaction).
  /// Held constant across themes — a brand action color shouldn't flip.
  static const ctaBlue = Color(0xFF416180);
  static const ctaBluePressed = Color(0xFF2C455D);

  /// Secondary accent — the logo mark's second tone, subtle highlights.
  static const lightBlue = Color(0xFF94BCE3);

  /// Amber/orange — money-related actions only (bids, prices, pay
  /// commission). Unchanged from the original palette.
  static const accent = Color(0xFFF2994A);

  /// Status-dot colors (UI/UX Brief §4). Always paired with a text label —
  /// never rely on color alone (§6). Unchanged from the original palette.
  static const statusLive = Color(0xFF2E7D32); // green: live/good
  static const statusIdle = Color(0xFF9E9E9E); // gray: unavailable/idle
  static const statusPending = Color(0xFFF2994A); // amber: pending/attention
  static const statusError = Color(0xFFD32F2F); // red: rejected/on hold/cancelled

  /// A soft border for a danger-outlined button (Log out, Report a
  /// Problem) — pairs with `statusError` text but is muted rather than a
  /// full-strength red outline; the dark-mode value keeps that same
  /// muted-red relationship instead of the light theme's pale pink reading
  /// as a stray near-white line on a dark surface.
  static Color get dangerBorder => _isDark ? const Color(0xFF4A2E2B) : const Color(0xFFE8CFC8);

  static Color get background => _isDark ? const Color(0xFF12191F) : const Color(0xFFF2F2F3);
  static Color get surface => _isDark ? const Color(0xFF1E2830) : const Color(0xFFFFFFFF);

  /// Subtle fills — dashed upload wells, info banners — distinct enough
  /// from `surface`/`background` to read as a third, quieter layer.
  static Color get surfaceSubtle => _isDark ? const Color(0xFF171F26) : const Color(0xFFFAFAFB);
  static Color get infoTint => _isDark ? const Color(0xFF16232E) : const Color(0xFFF6FAFF);

  /// A subtle warm highlight for a Plus-related row among otherwise plain
  /// ones (e.g. "Cargo Motives Plus" in the account menu) — a muted gold
  /// tint in dark mode rather than the light theme's cream, so it still
  /// reads as "a little special" without glaring against a dark surface.
  static Color get plusHighlight => _isDark ? const Color(0xFF2B2410) : const Color(0xFFFCF8EE);

  static Color get border => _isDark ? const Color(0xFF2C3944) : const Color(0xFFDEDFE2);

  /// Text ramp — primary body text down to placeholder-weight text.
  static Color get textPrimary => _isDark ? const Color(0xFFEDEFF0) : const Color(0xFF1D1F20);
  static Color get textLabel => _isDark ? const Color(0xFFB8BEC2) : const Color(0xFF5D5D60);
  static Color get textSecondary => _isDark ? const Color(0xFF9DA4A8) : const Color(0xFF7A7A7D);
  // Was 0xFF98989B (light) / 0xFF7C8388 (dark) — under ~3:1 contrast against
  // this app's own background/surface, well short of WCAG AA for text; only
  // safe for a placeholder glyph, not the timestamps/labels/subtitles this
  // token is actually used for throughout the app. Darkened (light) /
  // lightened (dark) for real legibility while staying visibly dimmer than
  // textSecondary.
  static Color get textTertiary => _isDark ? const Color(0xFF9AA1A6) : const Color(0xFF6E6E71);

  /// The placeholder map's own ground/grid tones (no `google_maps_flutter`
  /// key provisioned — see MapPlaceholder's docblock). Previously a fixed
  /// light cream regardless of theme, which put the theme-reactive floating
  /// back/zoom buttons at very low contrast against it in light mode (both
  /// near-white) and looked jarring in dark mode (a bright box in an
  /// otherwise dark UI) — reported live as "no back button" on Track
  /// Shipment, since it was there but hard to see.
  static Color get mapGround => _isDark ? const Color(0xFF0D141A) : const Color(0xFFEFEFEA);
  static Color get mapGridLine => _isDark ? const Color(0xFF223038) : const Color(0xFFE2E2DC);
}

/// App-wide ThemeData. Barlow Condensed for headings, Barlow for body —
/// bundled as local font assets (pubspec.yaml `fonts:`), not the
/// `google_fonts` package's runtime fetch, so typography never depends on
/// a network call on a patchy connection.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildRestoring(Brightness.light);

  static ThemeData get dark => _buildRestoring(Brightness.dark);

  /// Builds a ThemeData for [brightness] using AppColors's getters, but
  /// restores AppColors's ambient brightness flag to whatever it was
  /// before this call once done — merely *constructing* a ThemeData object
  /// (e.g. evaluating `theme: AppTheme.light, darkTheme: AppTheme.dark` as
  /// plain argument expressions) must never leave a lasting side effect on
  /// global state; only app.dart's `builder:` callback (see its own
  /// docblock) is allowed to durably set the flag for the widgets about to
  /// build. Without this restore, evaluating `AppTheme.dark` anywhere —
  /// including incidentally, e.g. a test pumping a widget that touches it —
  /// would leave every *other* widget's `AppColors.*` reads dark-mode-tinted
  /// until something else happened to flip it back.
  static ThemeData _buildRestoring(Brightness brightness) {
    final previous = AppColors.brightness;
    AppColors.setBrightness(brightness);
    final theme = _build(brightness);
    AppColors.setBrightness(previous);
    return theme;
  }

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.ctaBlue,
      brightness: brightness,
      primary: AppColors.ctaBlue,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    );

    const headingFont = 'Barlow Condensed';
    const bodyFont = 'Barlow';

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.primaryDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ctaBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ctaBlue.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(50), // large touch targets (Brief §6)
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: headingFont,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.ctaBlue)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 64,
        indicatorColor: AppColors.infoTint,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? AppColors.ctaBluePressed : AppColors.textTertiary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.ctaBluePressed : AppColors.textTertiary,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.ctaBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        hintStyle: TextStyle(color: AppColors.textTertiary),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontFamily: headingFont,
          fontWeight: FontWeight.w600,
          fontSize: 30,
          color: AppColors.primary,
        ),
        titleLarge: TextStyle(
          fontFamily: headingFont,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(fontFamily: bodyFont, fontSize: 16, color: AppColors.textPrimary),
        // bodyMedium is Material 3's fallback style for any plain Text()
        // widget with no explicit style/ancestor override — the *default*
        // text color needs to read clearly on its own; genuinely secondary
        // text should opt into AppColors.textSecondary explicitly, not the
        // other way around. Previously this used textSecondary directly,
        // which meant every unstyled (or partially-styled, e.g. just
        // fontWeight) Text() across the app rendered in the dimmer tone —
        // the real cause behind text reading as faded/hard-to-read in both
        // themes, reported live.
        bodyMedium: TextStyle(fontFamily: bodyFont, fontSize: 14, color: AppColors.textPrimary),
        labelSmall: TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textLabel,
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.surface),
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      iconTheme: IconThemeData(color: AppColors.textSecondary),
    );
  }
}
