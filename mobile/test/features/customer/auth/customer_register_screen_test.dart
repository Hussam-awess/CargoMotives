import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/customer/auth/customer_register_screen.dart';
import 'package:cargo_motives/features/customer/auth/data/customer_auth_repository.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_customer_auth_repository.dart';

Widget _appUnder({required FakeCustomerAuthRepository repository}) {
  final router = GoRouter(
    initialLocation: '/customer-register',
    routes: [
      GoRoute(
        path: '/customer-register',
        builder: (context, state) =>
            CustomerRegisterScreen(repository: repository),
      ),
      GoRoute(
        path: '/customer-otp',
        builder: (context, state) =>
            Text('OTP_SCREEN:${(state.extra! as CustomerRegistration).email}'),
      ),
      GoRoute(
        path: '/customer-login',
        builder: (context, state) => const Text('LOGIN_SCREEN'),
      ),
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

Future<void> _fillValidForm(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Amina Hassan');
  await tester.enterText(fields.at(1), 'amina@example.com');
  await tester.enterText(fields.at(2), '0712345678');
  await tester.enterText(fields.at(4), 'password123');
  await tester.enterText(fields.at(5), 'password123');
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
}

void main() {
  testWidgets('shows a validation error when full name is empty', (
    tester,
  ) async {
    final repository = FakeCustomerAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Enter your name.'), findsOneWidget);
  });

  testWidgets('shows a validation error when passwords do not match', (
    tester,
  ) async {
    final repository = FakeCustomerAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await _fillValidForm(tester);
    await tester.enterText(find.byType(TextField).at(5), 'different');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text("Passwords don't match."), findsOneWidget);
  });

  testWidgets('shows a validation error when Terms are not accepted', (
    tester,
  ) async {
    var registerCalled = false;
    final repository = FakeCustomerAuthRepository(
      onRegister: (registration) async => registerCalled = true,
    );
    await tester.pumpWidget(_appUnder(repository: repository));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Amina Hassan');
    await tester.enterText(fields.at(1), 'amina@example.com');
    await tester.enterText(fields.at(2), '0712345678');
    await tester.enterText(fields.at(4), 'password123');
    await tester.enterText(fields.at(5), 'password123');
    // Deliberately not tapping the Terms checkbox.
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(
      find.text('Please accept the Terms and Conditions to continue.'),
      findsOneWidget,
    );
    expect(registerCalled, isFalse);
  });

  testWidgets('registers and navigates to the email-OTP screen on success', (
    tester,
  ) async {
    CustomerRegistration? captured;
    final repository = FakeCustomerAuthRepository(
      onRegister: (registration) async => captured = registration,
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await _fillValidForm(tester);
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(captured?.email, 'amina@example.com');
    expect(captured?.fullName, 'Amina Hassan');
    expect(captured?.phoneNumber, '0712345678');
    expect(captured?.preferredCurrency, 'TZS');
    expect(find.text('OTP_SCREEN:amina@example.com'), findsOneWidget);
  });

  testWidgets('submits the chosen currency preference', (tester) async {
    CustomerRegistration? captured;
    final repository = FakeCustomerAuthRepository(
      onRegister: (registration) async => captured = registration,
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await _fillValidForm(tester);

    await tester.ensureVisible(find.text('USD'));
    await tester.tap(find.text('USD'));
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(captured?.preferredCurrency, 'USD');
  });

  testWidgets('shows the server error message on failure', (tester) async {
    final repository = FakeCustomerAuthRepository(
      onRegister: (registration) async => throw ApiException(
        'This email is already registered.',
        statusCode: 422,
        fieldErrors: {
          'email': ['This email is already registered.'],
        },
      ),
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await _fillValidForm(tester);
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('This email is already registered.'), findsOneWidget);
  });

  testWidgets('the login link navigates to the Customer login screen', (
    tester,
  ) async {
    final repository = FakeCustomerAuthRepository();
    await tester.pumpWidget(_appUnder(repository: repository));

    await tester.ensureVisible(find.textContaining('Log in'));
    await tester.tap(find.textContaining('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_SCREEN'), findsOneWidget);
  });
}
