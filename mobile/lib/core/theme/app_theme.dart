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
abstract final class AppColors {
  /// Navy — brand ink: splash background, headline text, dark surfaces.
  /// Dark enough on its own that a separate "darker" shade isn't needed
  /// for AppBar-foreground-on-white contrast, so `primaryDark` aliases it.
  static const primary = Color(0xFF1D2D3D);
  static const primaryDark = primary;

  /// Steel-blue — the one interactive/CTA color: primary buttons, links,
  /// focus rings. Distinct from `primary` (navy is ink, not an action
  /// color) and from `accent` (amber is money, not general interaction).
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
  static const statusError = Color(
    0xFFD32F2F,
  ); // red: rejected/on hold/cancelled

  static const background = Color(0xFFF2F2F3);
  static const surface = Color(0xFFFFFFFF);

  /// Subtle fills — dashed upload wells, info banners — distinct enough
  /// from `surface`/`background` to read as a third, quieter layer.
  static const surfaceSubtle = Color(0xFFFAFAFB);
  static const infoTint = Color(0xFFF6FAFF);

  static const border = Color(0xFFDEDFE2);

  /// Text ramp — primary body text down to placeholder-weight text.
  static const textPrimary = Color(0xFF1D1F20);
  static const textLabel = Color(0xFF5D5D60);
  static const textSecondary = Color(0xFF7A7A7D);
  static const textTertiary = Color(0xFF98989B);
}

/// App-wide ThemeData. Barlow Condensed for headings, Barlow for body —
/// bundled as local font assets (pubspec.yaml `fonts:`), not the
/// `google_fonts` package's runtime fetch, so typography never depends on
/// a network call on a patchy connection.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.ctaBlue,
      brightness: Brightness.light,
      primary: AppColors.ctaBlue,
      secondary: AppColors.accent,
    );

    const headingFont = 'Barlow Condensed';
    const bodyFont = 'Barlow';

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
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
          minimumSize: const Size.fromHeight(
            50,
          ), // large touch targets (Brief §6)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.ctaBlue),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.ctaBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
      ),
      textTheme: const TextTheme(
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
        ),
        bodyLarge: TextStyle(fontFamily: bodyFont, fontSize: 16),
        bodyMedium: TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textLabel,
        ),
      ),
    );
  }
}
