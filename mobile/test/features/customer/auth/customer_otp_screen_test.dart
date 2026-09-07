import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/customer/auth/customer_otp_screen.dart';
import 'package:cargo_motives/features/customer/auth/data/customer_auth_repository.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_customer_auth_repository.dart';
import '../../../support/fake_secure_storage_platform.dart';

const _registration = CustomerRegistration(
  fullName: 'Amina Hassan',
  email: 'amina@example.com',
  phoneNumber: '+255712345678',
  password: 'password123',
  passwordConfirmation: 'password123',
);

Widget _appUnder({required FakeCustomerAuthRepository repository}) {
  final router = GoRouter(
    initialLocation: '/customer-otp',
    routes: [
      GoRoute(
        path: '/customer-otp',
        builder: (context, state) => CustomerOtpScreen(
          registration: _registration,
          repository: repository,
          sessionStore: SessionStore(),
        ),
      ),
      GoRoute(
        path: '/customer',
        builder: (context, state) => const Text('CUSTOMER_HOME'),
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

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets('shows the email the code was sent to', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeCustomerAuthRepository()));

    expect(find.textContaining('amina@example.com'), findsOneWidget);
  });

  testWidgets('shows a validation error for a short code', (tester) async {
    var verifyCalled = false;
    final repository = FakeCustomerAuthRepository(
      onVerifyRegistration: ({required email, required code}) async {
        verifyCalled = true;
        return 'tok';
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Verify'));
    await tester.pump();

    expect(find.text('Enter the 6-digit code.'), findsOneWidget);
    expect(verifyCalled, isFalse);
  });

  testWidgets('verifying navigates to Customer Home on success', (tester) async {
    String? capturedCode;
    final repository = FakeCustomerAuthRepository(
      onVerifyRegistration: ({required email, required code}) async {
        capturedCode = code;
        return 'a-real-token';
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(capturedCode, '123456');
    expect(find.text('CUSTOMER_HOME'), findsOneWidget);
  });

  testWidgets('wrong code shows the server error and stays on the OTP screen', (tester) async {
    final repository = FakeCustomerAuthRepository(
      onVerifyRegistration: ({required email, required code}) async => throw ApiException(
        'That code is incorrect.',
        statusCode: 422,
        fieldErrors: {
          'code': ['That code is incorrect.'],
        },
      ),
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('That code is incorrect.'), findsOneWidget);
  });

  testWidgets('resend calls register() again with the same registration data', (tester) async {
    CustomerRegistration? resent;
    final repository = FakeCustomerAuthRepository(
      onRegister: (registration) async => resent = registration,
    );

    await tester.pumpWidget(_appUnder(repository: repository));

    expect(find.text('Resend code in 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Resend code'), findsOneWidget);

    await tester.tap(find.text('Resend code'));
    await tester.pump();

    expect(resent?.email, 'amina@example.com');
  });
}
