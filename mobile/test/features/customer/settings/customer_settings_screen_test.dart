import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/theme/theme_controller.dart';
import 'package:cargo_motives/core/theme/theme_scope.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/auth/edit_profile_screen.dart';
import 'package:cargo_motives/features/customer/auth/customer_forgot_password_screen.dart';
import 'package:cargo_motives/features/customer/settings/customer_settings_screen.dart';
import 'package:cargo_motives/features/support/active_sessions_screen.dart';
import 'package:cargo_motives/features/support/change_password_screen.dart';
import 'package:cargo_motives/features/support/delete_account_screen.dart';
import 'package:cargo_motives/features/support/settings_widgets.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_auth_repository.dart';
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
    'shows a Security section with Change password, 2FA, and Active sessions',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CustomerSettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
                email: 'amina@example.com',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('SECURITY'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Two-factor authentication'), findsOneWidget);
      expect(find.text('Active sessions'), findsOneWidget);
    },
  );

  testWidgets('tapping Active sessions opens the real session list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appUnder(
        CustomerSettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: 'Amina Hassan',
              companyName: null,
              isFeatured: false,
            ),
            onSessions: () async => [
              ActiveSession(id: 1, deviceName: 'Android device', lastUsedAt: DateTime(2026, 9, 24), createdAt: null, isCurrent: true),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Active sessions'),
      300,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.text('Active sessions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active sessions'));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveSessionsScreen), findsOneWidget);
    expect(find.text('Android device'), findsOneWidget);
    expect(find.text('This device'), findsOneWidget);
  });

  testWidgets('turning on two-factor asks for the password and saves it', (tester) async {
    bool? savedEnabled;
    String? savedPassword;
    await tester.pumpWidget(
      _appUnder(
        CustomerSettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false),
            onUpdateTwoFactor: (enabled, password) async {
              savedEnabled = enabled;
              savedPassword = password;
              return UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false, twoFactorEnabled: enabled);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.widgetWithText(SettingsToggleRow, 'Two-factor authentication');
    await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(find.text('Confirm your password'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(savedEnabled, isTrue);
    expect(savedPassword, 'secret123');
    expect(tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch))).value, isTrue);
  });

  testWidgets('cancelling the password prompt leaves two-factor off', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _appUnder(
        CustomerSettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false),
            onUpdateTwoFactor: (enabled, password) async {
              called = true;
              return const UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.widgetWithText(SettingsToggleRow, 'Two-factor authentication');
    await tester.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch))).value, isFalse);
  });

  testWidgets('SMS alerts and Promotions are off by default and save to the server', (tester) async {
    final saved = <Map<String, bool>>[];
    await tester.pumpWidget(
      _appUnder(
        CustomerSettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false),
            onUpdateNotificationPreferences: (preferences) async {
              saved.add(preferences);
              return UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
                notificationPreferences: {...UserProfile.defaultNotificationPreferences, ...preferences},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sms = find.widgetWithText(SettingsToggleRow, 'SMS alerts');
    await tester.scrollUntilVisible(sms, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.descendant(of: sms, matching: find.byType(Switch))).value, isFalse);

    await tester.tap(find.descendant(of: sms, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    final promotions = find.widgetWithText(SettingsToggleRow, 'Promotions');
    await tester.ensureVisible(promotions);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: promotions, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(saved, [
      {'sms_alerts': true},
      {'promotions': true},
    ]);
  });

  testWidgets('masks the registered phone number', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CustomerSettingsScreen(
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: 'Amina Hassan',
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
    'reflects the server notification preferences, not the LocalPrefs default',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CustomerSettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
                notificationPreferences: {
                  'bids': false,
                  'shipment_updates': true,
                  'messages': true,
                  'new_job_matches': true,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final newOffersRow = find.widgetWithText(SettingsToggleRow, 'New offers');
      await tester.scrollUntilVisible(
        newOffersRow,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(
        find.descendant(of: newOffersRow, matching: find.byType(Switch)),
      );
      expect(toggle.value, isFalse);
    },
  );

  testWidgets(
    'toggling shipment updates saves the shipment_updates category to the server',
    (tester) async {
      Map<String, bool>? saved;

      await tester.pumpWidget(
        _appUnder(
          CustomerSettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
              ),
              onUpdateNotificationPreferences: (preferences) async {
                saved = preferences;
                return const UserProfile(
                  fullName: 'Amina Hassan',
                  companyName: null,
                  isFeatured: false,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsToggleRow, 'Shipment updates');
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(saved, {'shipment_updates': false});
    },
  );

  testWidgets(
    'shows the customers preferred currency and lets them change it',
    (tester) async {
      String? saved;
      await tester.pumpWidget(
        _appUnder(
          CustomerSettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
                preferredCurrency: 'TZS',
              ),
              onUpdatePreferredCurrency: (currency) async {
                saved = currency;
                return UserProfile(
                  fullName: 'Amina Hassan',
                  companyName: null,
                  isFeatured: false,
                  preferredCurrency: currency,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.widgetWithText(SettingsNavRow, 'Currency');
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('TZS'), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();

      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();

      expect(saved, 'USD');
      expect(find.text('USD'), findsOneWidget);
    },
  );

  testWidgets(
    'toggling new messages saves the messages category to the server',
    (tester) async {
      Map<String, bool>? saved;

      await tester.pumpWidget(
        _appUnder(
          CustomerSettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
              ),
              onUpdateNotificationPreferences: (preferences) async {
                saved = preferences;
                return const UserProfile(
                  fullName: 'Amina Hassan',
                  companyName: null,
                  isFeatured: false,
                );
              },
            ),
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
    'Change password shows a forgot-password link that opens the Customer forgot-password screen',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
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

      expect(find.byType(CustomerForgotPasswordScreen), findsOneWidget);
    },
  );

  testWidgets(
    'logging out asks for confirmation and cancelling keeps the user on Settings',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
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

      expect(find.byType(CustomerSettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'confirming the logout dialog actually logs out and navigates to Welcome',
    (tester) async {
      var loggedOut = false;

      await tester.pumpWidget(
        _appUnderWithRouter(
          CustomerSettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
              ),
              onLogout: () async => loggedOut = true,
            ),
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
    'tapping the registered phone row opens Edit Profile, same as Email',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CustomerSettingsScreen(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
                phoneNumber: '+255712345678',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.text('+255 712 ••• 678');
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Delete account opens the real deletion screen',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
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

      final deleteButton = find.text('Delete account');
      await tester.scrollUntilVisible(
        deleteButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text('Delete my account'), findsOneWidget);
    },
  );
}
