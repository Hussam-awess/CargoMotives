import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/customer/settings/customer_settings_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

Widget _appUnder(Widget home) {
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

void main() {
  testWidgets('shows a Security section with Change password, 2FA, and Active sessions', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CustomerSettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async =>
                const UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false, email: 'amina@example.com'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('SECURITY'), 300, scrollable: scrollable);
    await tester.pumpAndSettle();

    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Two-factor authentication'), findsOneWidget);
    expect(find.text('Active sessions'), findsOneWidget);
  });

  testWidgets('tapping Active sessions shows an honest not-available dialog', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CustomerSettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Active sessions'), 300, scrollable: scrollable);
    await tester.ensureVisible(find.text('Active sessions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Viewing and managing active sessions isn\'t available in the app yet.'), findsOneWidget);
  });

  testWidgets('masks the registered phone number', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CustomerSettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async =>
                const UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false, phoneNumber: '+255712345678'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('+255 712 ••• 678'), 300, scrollable: scrollable);
    await tester.pumpAndSettle();

    expect(find.text('+255 712 ••• 678'), findsOneWidget);
    expect(find.text('+255712345678'), findsNothing);
  });
}
