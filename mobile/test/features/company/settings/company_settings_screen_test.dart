import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/theme/theme_controller.dart';
import 'package:cargo_motives/core/theme/theme_scope.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/company/data/featured_repository.dart';
import 'package:cargo_motives/features/company/settings/company_settings_screen.dart';
import 'package:cargo_motives/features/support/settings_widgets.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_company_featured_repository.dart';

Widget _appUnder(Widget home) {
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: ThemeScope(
      controller: ThemeController(false),
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'shows Company details & documents and Preferred lanes with a real saved count',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: null,
                companyName: null,
                isFeatured: false,
                phoneNumber: '+255712345678',
              ),
            ),
            featuredRepository: FakeCompanyFeaturedRepository(
              onStatus: () async => const CompanyFeaturedStatus(
                isFeatured: true,
                featuredUntil: null,
                price: 50000,
                durationDays: 30,
                preferredRoutes: [
                  PreferredRoute(
                    origin: 'Dar es Salaam',
                    destination: 'Mwanza',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Company details & documents'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('Company details & documents'), findsOneWidget);
      expect(find.text('Preferred lanes'), findsOneWidget);
      expect(find.text('1 saved'), findsOneWidget);
    },
  );

  testWidgets('masks the registered phone number', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CompanySettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: null,
              companyName: null,
              isFeatured: false,
              phoneNumber: '+255712345678',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('+255 712 ••• 678'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('+255 712 ••• 678'), findsOneWidget);
    expect(find.text('+255712345678'), findsNothing);
  });

  testWidgets(
    'toggling New matching loads saves the new_job_matches category to the server',
    (tester) async {
      Map<String, bool>? saved;

      await tester.pumpWidget(
        _appUnder(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: null,
                companyName: null,
                isFeatured: false,
              ),
              onUpdateNotificationPreferences: (preferences) async {
                saved = preferences;
                return const UserProfile(
                  fullName: null,
                  companyName: null,
                  isFeatured: false,
                );
              },
            ),
            featuredRepository: FakeCompanyFeaturedRepository(
              onStatus: () async => const CompanyFeaturedStatus(
                isFeatured: false,
                featuredUntil: null,
                price: 50000,
                durationDays: 30,
                preferredRoutes: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsToggleRow, 'New matching loads');
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(saved, {'new_job_matches': false});
    },
  );
}
