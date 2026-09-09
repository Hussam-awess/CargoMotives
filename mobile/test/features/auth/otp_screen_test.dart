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

const _args = OtpScreenArgs(
  phoneNumber: '+255712345678',
  role: AccountRole.transporterCompany,
  fullName: 'Juma Ally',
  email: 'juma@example.com',
  password: 'password123',
);

Widget _appUnder({required FakeAuthRepository repository}) {
  final router = GoRouter(
    initialLocation: '/otp',
    routes: [
      GoRoute(
        path: '/otp',
        builder: (context, state) => OtpScreen(
          args: _args,
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

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets(
    'shows a validation error for a short code without calling the repository',
    (tester) async {
      var verifyCalled = false;
      final repository = FakeAuthRepository(
        onVerifyOtp: (phone, role, code) async {
          verifyCalled = true;
          return const OtpVerifyResult(token: 't');
        },
      );

      await tester.pumpWidget(_appUnder(repository: repository));
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Verify'));
      await tester.pump();

      expect(find.text('Enter the 6-digit code.'), findsOneWidget);
      expect(verifyCalled, isFalse);
    },
  );

  testWidgets('a verified company lands on Company Home', (tester) async {
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, role, code) async =>
          const OtpVerifyResult(token: 'tok'),
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('COMPANY_HOME'), findsOneWidget);
  });

  testWidgets('the code is sent to verifyOtp', (tester) async {
    String? capturedCode;
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, role, code) async {
        capturedCode = code;
        return const OtpVerifyResult(token: 'tok');
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(capturedCode, '123456');
  });

  testWidgets('wrong code shows the server error and stays on the OTP screen', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, role, code) async {
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
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('That code is incorrect.'), findsOneWidget);
    expect(find.text('Verification code'), findsOneWidget);
  });

  testWidgets(
    'resend is disabled during cooldown and becomes available once it elapses, '
    'sending the same registration data again',
    (tester) async {
      var resendCount = 0;
      String? resentFullName;
      final repository = FakeAuthRepository(
        onRequestOtp: (phone, role, fullName, email, password) async {
          resendCount++;
          resentFullName = fullName;
        },
        onVerifyOtp: (phone, role, code) async =>
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
      expect(resentFullName, 'Juma Ally');
    },
  );
}
