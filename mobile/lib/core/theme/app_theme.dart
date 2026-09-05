import 'package:flutter/material.dart';

/// Cargo Motives design tokens (UI/UX Design Brief §4).
///
/// Deliberately small: one primary color for navigation/primary actions, one
/// accent color for money-related actions, and a fixed set of status colors.
/// The brief is explicit that this app should read as "familiar, not
/// invented" (like Uber/Bolt) — resist adding more colors/themes per feature
/// as later phases add screens.
abstract final class AppColors {
  /// Deep blue/teal — navigation, primary actions.
  static const primary = Color(0xFF0B4F6C);
  static const primaryDark = Color(0xFF08384D);

  /// Amber/orange — money-related actions only (bids, prices, pay commission).
  static const accent = Color(0xFFF2994A);

  /// Status-dot colors (UI/UX Brief §4). Always paired with a text label —
  /// never rely on color alone (§6).
  static const statusLive = Color(0xFF2E7D32); // green: live/good
  static const statusIdle = Color(0xFF9E9E9E); // gray: unavailable/idle
  static const statusPending = Color(0xFFF2994A); // amber: pending/attention
  static const statusError = Color(
    0xFFD32F2F,
  ); // red: rejected/on hold/cancelled

  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
}

/// App-wide ThemeData. One clean, legible sans-serif throughout (the
/// platform default — Roboto/San Francisco — rather than a bundled custom
/// font, per the brief's "familiar, not invented" direction and to avoid a
/// network font fetch on patchy connections).
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(
            52,
          ), // large touch targets (Brief §6)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 26),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        labelSmall: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      ),
    );
  }
}
