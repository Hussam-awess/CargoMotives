import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/theme/theme_controller.dart';
import 'package:cargo_motives/core/theme/theme_scope.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/company/auth/company_forgot_password_screen.dart';
import 'package:cargo_motives/features/company/data/featured_repository.dart';
import 'package:cargo_motives/features/company/settings/company_settings_screen.dart';
import 'package:cargo_motives/features/support/change_password_screen.dart';
import 'package:cargo_motives/features/support/settings_widgets.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_company_featured_repository.dart';
import '../../../support/fake_session_store.dart';

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

/// A GoRouter-backed variant — only the logout tests below need real
/// navigation (`_logout()` calls `context.go('/welcome')` on success),
/// every other test in this file uses the plain [_appUnder] above.
Widget _appUnderWithRouter(Widget settingsScreen) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (context, state) => settingsScreen),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const Text('WELCOME_SCREEN'),
      ),
    ],
  );
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: ThemeScope(
      controller: ThemeController(false),
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  testWidgets(
    'toggling new messages saves the messages category to the server',
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
            featuredRepository: FakeCompanyFeaturedRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsToggleRow, 'New messages');
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(saved, {'messages': false});
    },
  );

  testWidgets(
    'Change password shows a forgot-password link that opens the Company forgot-password screen',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: null,
                companyName: null,
                isFeatured: false,
              ),
            ),
            featuredRepository: FakeCompanyFeaturedRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsNavRow, 'Change password');
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordScreen), findsOneWidget);

      await tester.tap(find.text('or forgot password?'));
      await tester.pumpAndSettle();

      expect(find.byType(CompanyForgotPasswordScreen), findsOneWidget);
    },
  );

  testWidgets(
    'logging out asks for confirmation and cancelling keeps the user on Settings',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: null,
                companyName: null,
                isFeatured: false,
              ),
            ),
            featuredRepository: FakeCompanyFeaturedRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final logoutButton = find.text('Log out');
      await tester.scrollUntilVisible(
        logoutButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(CompanySettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'confirming the logout dialog actually logs out and navigates to Welcome',
    (tester) async {
      var loggedOut = false;

      await tester.pumpWidget(
        _appUnderWithRouter(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: null,
                companyName: null,
                isFeatured: false,
              ),
              onLogout: () async => loggedOut = true,
            ),
            featuredRepository: FakeCompanyFeaturedRepository(),
            sessionStore: FakeSessionStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final logoutButton = find.text('Log out');
      await tester.scrollUntilVisible(
        logoutButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Two "Log out" texts now exist: the dialog's confirm button and the
      // (still-visible-underneath) Settings screen's own button — the
      // confirm action is the last one in the tree.
      await tester.tap(find.text('Log out').last);
      await tester.pumpAndSettle();

      expect(loggedOut, isTrue);
      expect(find.text('WELCOME_SCREEN'), findsOneWidget);
    },
  );

  testWidgets(
    'the Learn section opens the GPS connection guide',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: null,
                companyName: null,
                isFeatured: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.text('How to connect your GPS provider');
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('Connect your GPS provider'), findsOneWidget);
    },
  );
}
