import 'package:cargo_motives/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    // AppColors' brightness is deliberately global, mutable state (see its
    // own docblock) — reset it so this file's tests never leak into
    // whichever test file happens to run next in the same isolate.
    AppColors.setBrightness(Brightness.light);
  });

  test('neutral tokens invert between light and dark', () {
    AppColors.setBrightness(Brightness.light);
    final lightBackground = AppColors.background;
    final lightText = AppColors.textPrimary;

    AppColors.setBrightness(Brightness.dark);
    final darkBackground = AppColors.background;
    final darkText = AppColors.textPrimary;

    expect(darkBackground, isNot(lightBackground));
    expect(darkText, isNot(lightText));
  });

  test('brand action colors stay constant across themes', () {
    AppColors.setBrightness(Brightness.light);
    final lightCta = AppColors.ctaBlue;

    AppColors.setBrightness(Brightness.dark);
    final darkCta = AppColors.ctaBlue;

    expect(darkCta, lightCta);
  });

  test('brandChip stays navy regardless of theme, unlike primary', () {
    AppColors.setBrightness(Brightness.light);
    expect(AppColors.brandChip, const Color(0xFF1D2D3D));
    final lightPrimary = AppColors.primary;

    AppColors.setBrightness(Brightness.dark);
    expect(AppColors.brandChip, const Color(0xFF1D2D3D));
    final darkPrimary = AppColors.primary;

    expect(darkPrimary, isNot(lightPrimary));
  });

  test(
    'constructing AppTheme.light/.dark does not leave a lasting side effect on AppColors',
    () {
      AppColors.setBrightness(Brightness.light);

      // Merely evaluating both theme getters (as MaterialApp's theme:/
      // darkTheme: arguments do on every rebuild) must not leak dark mode
      // into whatever brightness was ambient before this call.
      // ignore: unnecessary_statements
      AppTheme.light;
      // ignore: unnecessary_statements
      AppTheme.dark;

      expect(AppColors.brightness, Brightness.light);
    },
  );

  test('AppTheme.light and AppTheme.dark carry the correct brightness', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });
}
