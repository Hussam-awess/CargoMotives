import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/auth/otp_screen.dart';
import 'package:cargo_motives/features/auth/phone_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_secure_storage_platform.dart';

Widget _appUnder({
  required FakeAuthRepository repository,
  AccountRole role = AccountRole.customer,
}) {
  final router = GoRouter(
    initialLocation: '/otp',
    routes: [
      GoRoute(
        path: '/otp',
        builder: (context, state) => OtpScreen(
          args: OtpScreenArgs(phoneNumber: '+255712345678', role: role),
          authRepository: repository,
          sessionStore: SessionStore(),
        ),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const Text('PROFILE_SETUP'),
      ),
      GoRoute(
        path: '/customer',
        builder: (context, state) => const Text('CUSTOMER_HOME'),
      ),
      GoRoute(
        path: '/company',
        builder: (context, state) => const Text('COMPANY_HOME'),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
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
          return const OtpVerifyResult(token: 't', requiresProfileSetup: false);
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

  testWidgets('customer needing profile setup is routed to Profile Setup', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      onVerifyOtp: (phone, role, code) async =>
          const OtpVerifyResult(token: 'tok', requiresProfileSetup: true),
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE_SETUP'), findsOneWidget);
  });

  testWidgets(
    'customer with a complete profile is routed straight to Customer Home',
    (tester) async {
      final repository = FakeAuthRepository(
        onVerifyOtp: (phone, role, code) async =>
            const OtpVerifyResult(token: 'tok', requiresProfileSetup: false),
      );

      await tester.pumpWidget(_appUnder(repository: repository));
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.text('CUSTOMER_HOME'), findsOneWidget);
    },
  );

  testWidgets(
    'transporter company always lands on Company Home, ignoring requires_profile_setup',
    (tester) async {
      final repository = FakeAuthRepository(
        onVerifyOtp: (phone, role, code) async =>
            const OtpVerifyResult(token: 'tok', requiresProfileSetup: true),
      );

      await tester.pumpWidget(
        _appUnder(repository: repository, role: AccountRole.transporterCompany),
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.text('COMPANY_HOME'), findsOneWidget);
    },
  );

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
    'resend is disabled during cooldown and becomes available once it elapses',
    (tester) async {
      var resendCount = 0;
      final repository = FakeAuthRepository(
        onRequestOtp: (phone, role) async {
          resendCount++;
        },
        onVerifyOtp: (phone, role, code) async =>
            const OtpVerifyResult(token: 't', requiresProfileSetup: false),
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
