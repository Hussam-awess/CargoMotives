import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/auth/phone_entry_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';

Widget _appUnder({required FakeAuthRepository repository}) {
  final router = GoRouter(
    initialLocation: '/phone-entry',
    routes: [
      GoRoute(
        path: '/phone-entry',
        builder: (context, state) => PhoneEntryScreen(role: AccountRole.transporterCompany, authRepository: repository),
      ),
      GoRoute(path: '/otp', builder: (context, state) => Text('OTP_SCREEN:${(state.extra! as OtpScreenArgs).phoneNumber}')),
      GoRoute(path: '/company-login', builder: (context, state) => const Text('COMPANY_LOGIN_SCREEN')),
    ],
  );

  // PhoneEntryScreen's AppBar carries a LanguageMenuButton (Phase 11),
  // which reads LocaleScope — needs an ancestor here or it null-check-fails.
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

/// Fills phone, full name, email and password (in the order
/// PhoneEntryScreen builds them) but does NOT check the Terms box —
/// callers that need a fully-submittable form should also tap it.
Future<void> _fillForm(WidgetTester tester, {String phone = '0712345678'}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), phone);
  await tester.enterText(fields.at(1), 'Juma Ally');
  await tester.enterText(fields.at(2), 'juma@example.com');
  await tester.enterText(fields.at(3), 'password123');
}

void main() {
  testWidgets('shows a validation error and does not call the repository when phone is empty', (tester) async {
    var requestCalled = false;
    final repository = FakeAuthRepository(
      onRequestOtp: (phone, role, fullName, email, password) async {
        requestCalled = true;
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.tap(find.text('SEND VERIFICATION CODE'));
    await tester.pump();

    expect(find.text('Enter your phone number.'), findsOneWidget);
    expect(requestCalled, isFalse);
  });

  testWidgets('shows a validation error when the Terms checkbox is not accepted', (tester) async {
    var requestCalled = false;
    final repository = FakeAuthRepository(
      onRequestOtp: (phone, role, fullName, email, password) async {
        requestCalled = true;
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await _fillForm(tester);
    await tester.tap(find.text('SEND VERIFICATION CODE'));
    await tester.pump();

    expect(find.text('Please accept the Terms and Conditions to continue.'), findsOneWidget);
    expect(requestCalled, isFalse);
  });

  testWidgets('requests an OTP and navigates to the OTP screen on success', (tester) async {
    final repository = FakeAuthRepository(onRequestOtp: (phone, role, fullName, email, password) async {});

    await tester.pumpWidget(_appUnder(repository: repository));
    await _fillForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('SEND VERIFICATION CODE'));
    await tester.pumpAndSettle();

    expect(find.text('OTP_SCREEN:0712345678'), findsOneWidget);
  });

  testWidgets('full name, email and password are sent along with the request', (tester) async {
    String? capturedFullName;
    String? capturedEmail;
    String? capturedPassword;
    final repository = FakeAuthRepository(
      onRequestOtp: (phone, role, fullName, email, password) async {
        capturedFullName = fullName;
        capturedEmail = email;
        capturedPassword = password;
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await _fillForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('SEND VERIFICATION CODE'));
    await tester.pumpAndSettle();

    expect(capturedFullName, 'Juma Ally');
    expect(capturedEmail, 'juma@example.com');
    expect(capturedPassword, 'password123');
  });

  testWidgets('shows the server error message when the request fails', (tester) async {
    final repository = FakeAuthRepository(
      onRequestOtp: (phone, role, fullName, email, password) async {
        throw ApiException(
          'Invalid phone number.',
          statusCode: 422,
          fieldErrors: {
            'phone_number': ['Invalid phone number.'],
          },
        );
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    // A validly-shaped number the server still rejects for its own reasons
    // (e.g. already registered) — client-side format validation now
    // catches a malformed one before it ever reaches the repository, so
    // this exercises the server-error-surfacing path instead.
    await _fillForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('SEND VERIFICATION CODE'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid phone number.'), findsOneWidget);
    // Should NOT have navigated away on failure.
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('the login link navigates to the Transporter Company login screen', (tester) async {
    final repository = FakeAuthRepository();

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.ensureVisible(find.textContaining('Log in'));
    await tester.tap(find.textContaining('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('COMPANY_LOGIN_SCREEN'), findsOneWidget);
  });
}
