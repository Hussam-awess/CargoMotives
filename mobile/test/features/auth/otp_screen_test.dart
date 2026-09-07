import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/auth/otp_screen.dart';
import 'package:cargo_motives/features/auth/phone_entry_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_secure_storage_platform.dart';

Widget _appUnder({required FakeAuthRepository repository}) {
  final router = GoRouter(
    initialLocation: '/otp',
    routes: [
      GoRoute(
        path: '/otp',
        builder: (context, state) => OtpScreen(
          args: const OtpScreenArgs(
            phoneNumber: '+255712345678',
            role: AccountRole.transporterCompany,
          ),
          authRepository: repository,
          sessionStore: SessionStore(),
        ),
      ),
      GoRoute(
        path: '/company',
        builder: (context, state) => const Text('COMPANY_HOME'),
      ),
    ],
  );

  // OtpScreen's AppBar carries a LanguageMenuButton (Phase 11), which
  // reads LocaleScope — needs an ancestor here or it null-check-fails.
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

/// The code, full_name, and email fields, in the order OtpScreen builds
/// them — Phase 11 added full_name/email here (Transporter Company's
/// "Step 1 — Account authentication" collects them alongside phone+OTP).
Future<void> _fillForm(
  WidgetTester tester, {
  String code = '123456',
  String fullName = 'Juma Ally',
  String email = 'juma@example.com',
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), code);
  await tester.enterText(fields.at(1), fullName);
  await tester.enterText(fields.at(2), email);
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets(
    'shows a validation error for a short code without calling the repository',
    (tester) async {
      var verifyCalled = false;
      final repository = FakeAuthRepository(
        onVerifyOtp: (phone, role, code, fullName, email) async {
          verifyCalled = true;
          return const OtpVerifyResult(token: 't');
        },
      );

      await tester.pumpWidget(_appUnder(repository: repository));
      await _fillForm(tester, code: '123');
      await tester.tap(find.text('Verify'));
      await tester.pump();

      expect(find.text('Enter the 6-digit code.'), findsOneWidget);
      expect(verifyCalled, isFalse);
    },
  );

  testWidgets(
    'shows a validation error when full name is missing',
    (tester) async {
      final repository = FakeAuthRepository();

      await tester.pumpWidget(_appUnder(repository: repository));
      await _fillForm(tester, fullName: '');
      await tester.tap(find.text('Verify'));
      await tester.pump();

      expect(find.text('Enter your name.'), findsOneWidget);
    },
  );

  testWidgets('a verified company lands on Company Home', (tester) async {
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, role, code, fullName, email) async =>
          const OtpVerifyResult(token: 'tok'),
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await _fillForm(tester);
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('COMPANY_HOME'), findsOneWidget);
  });

  testWidgets(
    'full_name and email are sent along with the code',
    (tester) async {
      String? capturedFullName;
      String? capturedEmail;
      final repository = FakeAuthRepository(
        onVerifyOtp: (phone, role, code, fullName, email) async {
          capturedFullName = fullName;
          capturedEmail = email;
          return const OtpVerifyResult(token: 'tok');
        },
      );

      await tester.pumpWidget(_appUnder(repository: repository));
      await _fillForm(tester, fullName: 'Juma Ally', email: 'juma@example.com');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(capturedFullName, 'Juma Ally');
      expect(capturedEmail, 'juma@example.com');
    },
  );

  testWidgets('wrong code shows the server error and stays on the OTP screen', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, role, code, fullName, email) async {
        throw ApiException(
          'That code is incorrect.',
          statusCode: 422,
          fieldErrors: {
            'code': ['That code is incorrect.'],
          },
        );
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await _fillForm(tester, code: '000000');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('That code is incorrect.'), findsOneWidget);
    expect(find.text('Verification code'), findsOneWidget);
  });

  testWidgets(
    'resend is disabled during cooldown and becomes available once it elapses',
    (tester) async {
      var resendCount = 0;
      final repository = FakeAuthRepository(
        onRequestOtp: (phone, role) async {
          resendCount++;
        },
        onVerifyOtp: (phone, role, code, fullName, email) async =>
            const OtpVerifyResult(token: 't'),
      );

      await tester.pumpWidget(_appUnder(repository: repository));

      expect(find.text('Resend code in 60s'), findsOneWidget);
      await tester.tap(find.text('Resend code in 60s'));
      await tester.pump();
      expect(
        resendCount,
        0,
        reason: 'tapping during cooldown must not trigger a resend',
      );

      await tester.pump(const Duration(seconds: 60));
      expect(find.text('Resend code'), findsOneWidget);

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      expect(resendCount, 1);
    },
  );
}
