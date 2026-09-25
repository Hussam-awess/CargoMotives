import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/core/local/local_prefs.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/customer/auth/customer_forgot_password_screen.dart';
import 'package:cargo_motives/features/auth/data/two_factor_repository.dart';
import 'package:cargo_motives/features/auth/two_factor_code_screen.dart';
import 'package:cargo_motives/features/customer/auth/customer_login_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_customer_auth_repository.dart';
import '../../../support/fake_secure_storage_platform.dart';
import '../../../support/fake_two_factor_repository.dart';

Widget _appUnder({
  required FakeCustomerAuthRepository repository,
  LocalPrefs prefs = const LocalPrefs(),
  FakeTwoFactorRepository? twoFactorRepository,
}) {
  final router = GoRouter(
    initialLocation: '/customer-login',
    routes: [
      GoRoute(
        path: '/customer-login',
        builder: (context, state) =>
            CustomerLoginScreen(
              repository: repository,
              sessionStore: SessionStore(),
              prefs: prefs,
              twoFactorRepository: twoFactorRepository,
            ),
      ),
      GoRoute(path: '/customer-register', builder: (context, state) => const Text('REGISTER_SCREEN')),
      GoRoute(path: '/customer', builder: (context, state) => const Text('CUSTOMER_HOME')),
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

  testWidgets('shows a validation error when email is empty', (tester) async {
    final repository = FakeCustomerAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
  });

  testWidgets('logs in and navigates to Customer Home on success', (tester) async {
    String? capturedEmail;
    final repository = FakeCustomerAuthRepository(
      onLogin: ({required email, required password}) async {
        capturedEmail = email;
        return 'a-real-token';
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField).at(0), 'amina@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(capturedEmail, 'amina@example.com');
    expect(find.text('CUSTOMER_HOME'), findsOneWidget);
  });

  testWidgets('shows the server error message on invalid credentials', (tester) async {
    final repository = FakeCustomerAuthRepository(
      onLogin: ({required email, required password}) async => throw ApiException(
        'Invalid credentials.',
        statusCode: 422,
        fieldErrors: {
          'email': ['Invalid credentials.'],
        },
      ),
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField).at(0), 'amina@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials.'), findsOneWidget);
  });

  testWidgets('the sign-up link navigates to the Customer register screen', (tester) async {
    final repository = FakeCustomerAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await tester.tap(find.textContaining('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('REGISTER_SCREEN'), findsOneWidget);
  });

  testWidgets('the "Forgot password?" link opens the reset flow', (tester) async {
    final repository = FakeCustomerAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerForgotPasswordScreen), findsOneWidget);
  });

  testWidgets('checking "Remember me" saves the email for next time, not the password', (tester) async {
    final repository = FakeCustomerAuthRepository(onLogin: ({required email, required password}) async => 'a-real-token');
    final prefs = const LocalPrefs();

    await tester.pumpWidget(_appUnder(repository: repository, prefs: prefs));
    await tester.enterText(find.byType(TextField).at(0), 'amina@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(await prefs.getBool('customer_login_remember_me', defaultValue: false), isTrue);
    expect(await prefs.getString('customer_login_remembered_email'), 'amina@example.com');
  });

  testWidgets('logging in without "Remember me" checked forgets any previously remembered email', (tester) async {
    SharedPreferences.setMockInitialValues({
      'customer_login_remember_me': true,
      'customer_login_remembered_email': 'old@example.com',
    });
    final repository = FakeCustomerAuthRepository(onLogin: ({required email, required password}) async => 'a-real-token');
    final prefs = const LocalPrefs();

    await tester.pumpWidget(_appUnder(repository: repository, prefs: prefs));
    await tester.pumpAndSettle();
    // Pre-filled from the previously remembered email, then uncheck it.
    await tester.tap(find.byType(Checkbox));
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(await prefs.getBool('customer_login_remember_me', defaultValue: false), isFalse);
    expect(await prefs.getString('customer_login_remembered_email'), isNull);
  });

  testWidgets('pre-fills the email field from a previously remembered login', (tester) async {
    SharedPreferences.setMockInitialValues({
      'customer_login_remember_me': true,
      'customer_login_remembered_email': 'amina@example.com',
    });
    final repository = FakeCustomerAuthRepository();

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(emailField.controller!.text, 'amina@example.com');
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
  testWidgets('an account with two-factor on is asked for the emailed code before signing in', (tester) async {
    String? verifiedCode;
    final repository = FakeCustomerAuthRepository(
      onLogin: ({required email, required password}) async => throw const TwoFactorRequired(
        challengeToken: 'challenge',
        channel: 'email',
        destination: 'a****@example.com',
      ),
    );
    final twoFactor = FakeTwoFactorRepository(
      onVerify: (challengeToken, code) async {
        verifiedCode = code;
        return 'token-after-2fa';
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository, twoFactorRepository: twoFactor));
    await tester.enterText(find.byType(TextField).at(0), 'amina@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.byType(TwoFactorCodeScreen), findsOneWidget);
    expect(find.text('We sent a code by email to a****@example.com.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('twoFactorCodeField')), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pumpAndSettle();

    expect(verifiedCode, '123456');
    expect(find.text('CUSTOMER_HOME'), findsOneWidget);
  });

  testWidgets('backing out of the two-factor step leaves the user on the login screen', (tester) async {
    final repository = FakeCustomerAuthRepository(
      onLogin: ({required email, required password}) async =>
          throw const TwoFactorRequired(challengeToken: 'challenge', channel: 'email', destination: 'a****@example.com'),
    );

    await tester.pumpWidget(_appUnder(repository: repository, twoFactorRepository: FakeTwoFactorRepository()));
    await tester.enterText(find.byType(TextField).at(0), 'amina@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(CustomerLoginScreen), findsOneWidget);
    expect(find.text('CUSTOMER_HOME'), findsNothing);
  });
}
