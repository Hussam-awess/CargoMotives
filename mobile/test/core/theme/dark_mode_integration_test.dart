import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/theme/app_theme.dart';
import 'package:cargo_motives/core/theme/theme_controller.dart';
import 'package:cargo_motives/core/theme/theme_scope.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/customer/settings/customer_settings_screen.dart';
import 'package:cargo_motives/features/support/settings_widgets.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

/// A minimal stand-in for CargoMotivesApp's own AnimatedBuilder-driven
/// MaterialApp (see app.dart) — real enough to prove the Dark mode toggle
/// actually flips the *app's* active theme end to end, not just a local
/// widget flag.
Widget _harness(ThemeController themeController, Widget home) {
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: ThemeScope(
      controller: themeController,
      child: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.value ? ThemeMode.dark : ThemeMode.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // Mirrors app.dart's own builder: callback — see AppTheme.light/
          // .dark's docblock for why evaluating them above doesn't durably
          // set AppColors's brightness on its own.
          builder: (context, child) {
            AppColors.setBrightness(
              themeController.value ? Brightness.dark : Brightness.light,
            );
            return child!;
          },
          home: home,
        ),
      ),
    ),
  );
}

void main() {
  tearDown(() => AppColors.setBrightness(Brightness.light));

  testWidgets(
    'toggling Dark mode in Settings flips the app-wide active theme',
    (tester) async {
      final themeController = ThemeController(false);

      await tester.pumpWidget(
        _harness(
          themeController,
          CustomerSettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldContextBefore = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(scaffoldContextBefore).brightness, Brightness.light);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Dark mode'),
        300,
        scrollable: scrollable,
      );
      final darkModeRow = find.widgetWithText(SettingsToggleRow, 'Dark mode');
      await tester.tap(
        find.descendant(of: darkModeRow, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      expect(themeController.value, isTrue);

      final scaffoldContextAfter = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(scaffoldContextAfter).brightness, Brightness.dark);
      expect(AppColors.background, isNot(const Color(0xFFF2F2F3)));
    },
  );
}
