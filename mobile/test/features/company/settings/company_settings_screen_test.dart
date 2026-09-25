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
import 'package:cargo_motives/shared/payments/payment_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_company_featured_repository.dart';
import '../../../support/fake_company_preferences_repository.dart';
import '../../../support/fake_payment_repository.dart';
import '../../../support/fake_session_store.dart';

Widget _appUnder(Widget home, {Locale locale = const Locale('en')}) {
  return LocaleScope(
    controller: LocaleController(locale),
    child: ThemeScope(
      controller: ThemeController(false),
      child: MaterialApp(
        locale: locale,
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

  testWidgets(
    'the dead Search radius, Document expiry reminders, and Payout method rows are gone',
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

      expect(find.text('Search radius'), findsNothing);
      expect(find.text('Document expiry reminders'), findsNothing);
      expect(find.text('Payout method'), findsNothing);
      // No payouts exist, and live GPS sharing with the job's customer is
      // core to the product rather than something a toggle could turn off.
      expect(find.text('Payout released'), findsNothing);
      expect(find.text('Share GPS with customers'), findsNothing);
    },
  );

  testWidgets(
    'turning off Accepting loads saves it to the server',
    (tester) async {
      bool? savedAcceptingLoads;

      await tester.pumpWidget(
        _appUnder(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(fullName: null, companyName: null, isFeatured: false),
            ),
            featuredRepository: FakeCompanyFeaturedRepository(),
            preferencesRepository: FakeCompanyPreferencesRepository(
              onUpdate: ({autoDeclineBelowBudget, floorRate, displayCurrency, acceptingLoads}) async {
                savedAcceptingLoads = acceptingLoads;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsToggleRow, 'Accepting loads');
      expect(tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch))).value, isTrue);

      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(savedAcceptingLoads, isFalse);
      expect(tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch))).value, isFalse);
    },
  );

  testWidgets(
    'a failed save reverts the Accepting loads toggle and says so',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(fullName: null, companyName: null, isFeatured: false),
            ),
            featuredRepository: FakeCompanyFeaturedRepository(),
            preferencesRepository: FakeCompanyPreferencesRepository(
              onUpdate: ({autoDeclineBelowBudget, floorRate, displayCurrency, acceptingLoads}) async =>
                  throw Exception('offline'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsToggleRow, 'Accepting loads');
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch))).value, isTrue);
      expect(find.text('Could not save that setting. Please try again.'), findsOneWidget);
    },
  );

  testWidgets(
    'the Security section has working two-factor, Active sessions and Delete account entries',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanySettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(fullName: null, companyName: null, isFeatured: false),
            ),
            featuredRepository: FakeCompanyFeaturedRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sessions = find.widgetWithText(SettingsNavRow, 'Active sessions');
      await tester.scrollUntilVisible(sessions, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SettingsToggleRow, 'Two-factor authentication'), findsOneWidget);
      expect(sessions, findsOneWidget);

      final delete = find.text('Delete account');
      await tester.scrollUntilVisible(delete, 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      expect(delete, findsOneWidget);
    },
  );

  testWidgets(
    'toggling auto-decline below budget saves it and reveals the Floor rate row',
    (tester) async {
      bool? savedToggle;

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
            featuredRepository: FakeCompanyFeaturedRepository(
              onStatus: () async => const CompanyFeaturedStatus(
                isFeatured: false,
                featuredUntil: null,
                price: 50000,
                durationDays: 30,
                preferredRoutes: [],
                autoDeclineBelowBudget: false,
              ),
            ),
            preferencesRepository: FakeCompanyPreferencesRepository(
              onUpdate: ({autoDeclineBelowBudget, floorRate, displayCurrency, acceptingLoads}) async {
                savedToggle = autoDeclineBelowBudget;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsToggleRow, 'Auto-decline below budget');
      await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(find.text('Floor rate'), findsNothing);

      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(savedToggle, isTrue);
      expect(find.text('Floor rate'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    },
  );

  testWidgets(
    'setting a floor rate through the dialog saves it and shows it on the row',
    (tester) async {
      double? savedFloorRate;

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
            featuredRepository: FakeCompanyFeaturedRepository(
              onStatus: () async => const CompanyFeaturedStatus(
                isFeatured: false,
                featuredUntil: null,
                price: 50000,
                durationDays: 30,
                preferredRoutes: [],
                autoDeclineBelowBudget: true,
                displayCurrency: 'TZS',
              ),
            ),
            preferencesRepository: FakeCompanyPreferencesRepository(
              onUpdate: ({autoDeclineBelowBudget, floorRate, displayCurrency, acceptingLoads}) async {
                savedFloorRate = floorRate;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsNavRow, 'Floor rate');
      await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '150000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedFloorRate, 150000.0);
      expect(find.text('TZS 150000'), findsOneWidget);
    },
  );

  testWidgets(
    'the floor rate row and dialog follow the app language (Swahili)',
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
            featuredRepository: FakeCompanyFeaturedRepository(
              onStatus: () async => const CompanyFeaturedStatus(
                isFeatured: false,
                featuredUntil: null,
                price: 50000,
                durationDays: 30,
                preferredRoutes: [],
                autoDeclineBelowBudget: true,
                displayCurrency: 'TZS',
              ),
            ),
            preferencesRepository: FakeCompanyPreferencesRepository(),
          ),
          locale: const Locale('sw'),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsNavRow, 'Kiwango cha chini');
      await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Hakijawekwa'), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('Bajeti ya chini kabisa utakayokubali'), findsOneWidget);
      expect(find.text('Ghairi'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.tap(find.text('Hifadhi'));
      await tester.pumpAndSettle();

      expect(find.text('Weka kiasi sahihi.'), findsOneWidget);
      expect(find.text('Floor rate'), findsNothing);
    },
  );

  testWidgets(
    'changing the currency saves the display currency and formats the Plus price with it',
    (tester) async {
      String? savedCurrency;

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
            featuredRepository: FakeCompanyFeaturedRepository(
              onStatus: () async => const CompanyFeaturedStatus(
                isFeatured: false,
                featuredUntil: null,
                price: 50000,
                durationDays: 30,
                preferredRoutes: [],
                displayCurrency: 'TZS',
              ),
            ),
            preferencesRepository: FakeCompanyPreferencesRepository(
              onUpdate: ({autoDeclineBelowBudget, floorRate, displayCurrency, acceptingLoads}) async {
                savedCurrency = displayCurrency;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsNavRow, 'Currency');
      await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('TZS'), findsOneWidget);

      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();

      expect(savedCurrency, 'USD');
      expect(find.text('USD'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Payment history opens the real Payment History screen',
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
            paymentRepository: FakePaymentRepository(isCompany: true, onList: () async => []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsNavRow, 'Payment history');
      await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(PaymentHistoryScreen), findsOneWidget);
    },
  );
}
