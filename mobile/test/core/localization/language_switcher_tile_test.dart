import 'package:cargo_motives/core/localization/language_switcher_tile.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_secure_storage_platform.dart';

Widget _appUnder(LocaleController controller, FakeAuthRepository repository) {
  return LocaleScope(
    controller: controller,
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: LanguageSwitcherTile(authRepository: repository)),
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets('shows English selected by default and switches to Kiswahili on tap', (tester) async {
    String? syncedLanguage;
    final controller = LocaleController(LocaleController.defaultLocale);
    final repository = FakeAuthRepository(
      onUpdateLanguagePreference: (code) async => syncedLanguage = code,
    );

    await tester.pumpWidget(_appUnder(controller, repository));

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Kiswahili'), findsOneWidget);

    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();

    expect(controller.value, const Locale('sw'));
    expect(syncedLanguage, 'sw');
  });

  testWidgets('a repository failure does not crash the switcher', (tester) async {
    final controller = LocaleController(LocaleController.defaultLocale);
    final repository = FakeAuthRepository(
      onUpdateLanguagePreference: (code) async => throw Exception('offline'),
    );

    await tester.pumpWidget(_appUnder(controller, repository));
    await tester.tap(find.text('Kiswahili'));
    await tester.pumpAndSettle();

    // The on-device locale still changed — syncing to the backend is
    // best-effort, never a precondition for the switch itself taking
    // effect (see LanguageSwitcherTile's docblock).
    expect(controller.value, const Locale('sw'));
  });
}
