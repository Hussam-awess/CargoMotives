import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/customer/auth/customer_forgot_password_screen.dart';
import 'package:cargo_motives/features/customer/auth/customer_login_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_customer_auth_repository.dart';
import '../../../support/fake_secure_storage_platform.dart';

Widget _appUnder({required FakeCustomerAuthRepository repository}) {
  final router = GoRouter(
    initialLocation: '/customer-login',
    routes: [
      GoRoute(
        path: '/customer-login',
        builder: (context, state) => CustomerLoginScreen(repository: repository, sessionStore: SessionStore()),
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
}
