import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/core/local/local_prefs.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/company/auth/company_forgot_password_screen.dart';
import 'package:cargo_motives/features/company/auth/company_login_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_secure_storage_platform.dart';

Widget _appUnder({required FakeAuthRepository repository, LocalPrefs prefs = const LocalPrefs()}) {
  final router = GoRouter(
    initialLocation: '/company-login',
    routes: [
      GoRoute(
        path: '/company-login',
        builder: (context, state) =>
            CompanyLoginScreen(repository: repository, sessionStore: SessionStore(), prefs: prefs),
      ),
      GoRoute(path: '/phone-entry', builder: (context, state) => const Text('PHONE_ENTRY_SCREEN')),
      GoRoute(path: '/company', builder: (context, state) => const Text('COMPANY_HOME')),
    ],
  );

  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows a validation error when phone is empty', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pump();

    expect(find.text('Enter your phone number.'), findsOneWidget);
  });

  testWidgets('logs in and navigates to Company Home on success', (tester) async {
    String? capturedPhone;
    final repository = FakeAuthRepository(
      onLogin: (phone, password) async {
        capturedPhone = phone;
        return 'a-real-token';
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField).at(0), '0712345678');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(capturedPhone, '0712345678');
    expect(find.text('COMPANY_HOME'), findsOneWidget);
  });

  testWidgets('shows the server error message on invalid credentials', (tester) async {
    final repository = FakeAuthRepository(
      onLogin: (phone, password) async => throw ApiException(
        'Invalid credentials.',
        statusCode: 422,
        fieldErrors: {
          'phone_number': ['Invalid credentials.'],
        },
      ),
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField).at(0), '0712345678');
    await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials.'), findsOneWidget);
  });

  testWidgets('the sign-up link navigates to the Phone Entry screen', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await tester.tap(find.textContaining('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('PHONE_ENTRY_SCREEN'), findsOneWidget);
  });

  testWidgets('the "Forgot password?" link opens the reset flow', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.byType(CompanyForgotPasswordScreen), findsOneWidget);
  });

  testWidgets('checking "Remember me" saves the phone number for next time, not the password', (tester) async {
    final repository = FakeAuthRepository(onLogin: (phone, password) async => 'a-real-token');
    final prefs = const LocalPrefs();

    await tester.pumpWidget(_appUnder(repository: repository, prefs: prefs));
    await tester.enterText(find.byType(TextField).at(0), '0712345678');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(await prefs.getBool('company_login_remember_me', defaultValue: false), isTrue);
    expect(await prefs.getString('company_login_remembered_phone'), '0712345678');
  });

  testWidgets('logging in without "Remember me" checked forgets any previously remembered phone', (tester) async {
    SharedPreferences.setMockInitialValues({
      'company_login_remember_me': true,
      'company_login_remembered_phone': '0700000000',
    });
    final repository = FakeAuthRepository(onLogin: (phone, password) async => 'a-real-token');
    final prefs = const LocalPrefs();

    await tester.pumpWidget(_appUnder(repository: repository, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(await prefs.getBool('company_login_remember_me', defaultValue: false), isFalse);
    expect(await prefs.getString('company_login_remembered_phone'), isNull);
  });

  testWidgets('pre-fills the phone field from a previously remembered login', (tester) async {
    SharedPreferences.setMockInitialValues({
      'company_login_remember_me': true,
      'company_login_remembered_phone': '0712345678',
    });
    final repository = FakeAuthRepository();

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.pumpAndSettle();

    final phoneField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(phoneField.controller!.text, '0712345678');
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
